"""
回归保障：难度体系引入后，模拟答题 (assemble_question_set) 路径的不变量。

此脚本为静态契约检查，不连 DB：
1. question_dedup.py 不引用任何 'difficulty' 相关标签或模块
2. assemble_question_set 函数签名与主流程不依赖难度分档
3. difficulty_allocator 模块未被意外导入到去重/组卷模块

可直接用 `python knowledge_service/test_practice_difficulty_invariant.py` 运行；
若有 drift 则以非零状态退出。
"""

from __future__ import annotations

import ast
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent
DEDUP = REPO / "app" / "services" / "question_dedup.py"


def _fail(msg: str) -> None:
    print(f"[REGRESSION FAIL] {msg}")
    sys.exit(1)


def main() -> None:
    if not DEDUP.exists():
        _fail(f"file not found: {DEDUP}")

    source = DEDUP.read_text(encoding="utf-8")
    tree = ast.parse(source)

    # 1) 文件不得出现 difficulty 关键字 / 难度标签名
    banned_tokens = ("difficulty", "difficulty_allocator", "简单", "一般", "困难")
    offenders: list[str] = []
    for line_no, line in enumerate(source.splitlines(), 1):
        # 允许在注释/docstring 出现；此处只排查代码行（粗略跳过 # 开头）
        stripped = line.lstrip()
        if stripped.startswith("#"):
            continue
        for token in banned_tokens:
            if token in line:
                offenders.append(f"line {line_no}: {line.strip()} [contains '{token}']")
    if offenders:
        _fail(
            "question_dedup.py 意外引入难度相关引用（应保持难度无关）:\n  "
            + "\n  ".join(offenders)
        )

    # 2) assemble_question_set 签名保持原样
    assemble = None
    for node in tree.body:
        if isinstance(node, ast.FunctionDef) and node.name == "assemble_question_set":
            assemble = node
            break
    if assemble is None:
        _fail("assemble_question_set not found in question_dedup.py")

    expected_args = [
        "candidates_by_type",
        "count_ranges",
        "db",
        "supplement_ctx",
    ]
    actual_args = [a.arg for a in assemble.args.args]
    if actual_args != expected_args:
        _fail(
            f"assemble_question_set 签名发生变化。"
            f"\n  期望: {expected_args}"
            f"\n  实际: {actual_args}"
        )

    # 3) 不得导入 difficulty_allocator
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom):
            if node.module and "difficulty_allocator" in node.module:
                _fail(
                    f"question_dedup.py 不得导入 difficulty_allocator（line {node.lineno}）"
                )
        elif isinstance(node, ast.Import):
            for alias in node.names:
                if "difficulty_allocator" in alias.name:
                    _fail(
                        f"question_dedup.py 不得导入 difficulty_allocator（line {node.lineno}）"
                    )

    print("[REGRESSION OK] assemble_question_set 路径难度无关，签名稳定")


if __name__ == "__main__":
    main()
