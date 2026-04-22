"""
难度策略解析与 Hamilton 最大余数分配。

四种 mode：
- single            → 全部题目归一个难度
- ratio             → 自定义 {简单,一般,困难} 百分比（和必须为 100）
- exam_sprint       → 预设 0/70/30（考试冲刺）
- beginner_friendly → 预设 60/40/0（入门友好）

分配算法 Hamilton 最大余数：按小数部分降序把多出的名额补足，保证 sum == total。
"""

from __future__ import annotations

import unicodedata
from typing import Dict, Optional

LEVELS = ("简单", "一般", "困难")


def _normalize_level(level: Optional[str]) -> str:
    """strip 空白 + NFC 归一，避免零宽字符/全角空格导致的失败。"""
    return unicodedata.normalize("NFC", (level or "").strip())

_PRESETS: Dict[str, Dict[str, int]] = {
    "exam_sprint": {"简单": 0, "一般": 70, "困难": 30},
    "beginner_friendly": {"简单": 60, "一般": 40, "困难": 0},
}


def allocate(total: int, ratio: Dict[str, int]) -> Dict[str, int]:
    """按 Hamilton 最大余数法把 total 分配到 ratio 指定的三档。

    - ratio 的键必须是 LEVELS 的子集；缺省档按 0 处理。
    - ratio 值总和必须为 100。
    - 单档为 0 允许（意味着跳过）。
    - total < 0 直接抛错；total = 0 时返回全 0。
    """
    if total < 0:
        raise ValueError(f"total 不能为负: {total}")

    normalized = {level: int(ratio.get(level, 0)) for level in LEVELS}
    for level, val in normalized.items():
        if val < 0:
            raise ValueError(f"ratio[{level}] 不能为负: {val}")
    if sum(normalized.values()) != 100:
        raise ValueError(f"ratio 总和必须为 100，当前: {normalized}")

    if total == 0:
        return dict.fromkeys(LEVELS, 0)

    raw = {level: total * normalized[level] / 100.0 for level in LEVELS}
    floors = {level: int(raw[level]) for level in LEVELS}
    remainder = total - sum(floors.values())
    if remainder > 0:
        # 按小数部分降序（稳定排序：平局时按 LEVELS 默认顺序）
        order = sorted(
            LEVELS,
            key=lambda level: (-(raw[level] - floors[level]), LEVELS.index(level)),
        )
        for level in order[:remainder]:
            floors[level] += 1
    return floors


def resolve_strategy(strategy: Optional[dict]) -> Optional[Dict[str, int]]:
    """把策略字典解析为 {简单, 一般, 困难} 的百分比分配。

    None → 返回 None（调用方走不分档的原流程）
    """
    if strategy is None:
        return None
    if not isinstance(strategy, dict):
        raise ValueError(f"strategy 必须是 dict，当前: {type(strategy).__name__}")

    mode = (strategy.get("mode") or "").strip().lower()
    if mode == "single":
        level = _normalize_level(strategy.get("level"))
        if level not in LEVELS:
            raise ValueError(f"single 模式需指定 level ∈ {LEVELS}，当前: {strategy.get('level')!r}")
        return {lvl: (100 if lvl == level else 0) for lvl in LEVELS}
    if mode == "ratio":
        raw_ratio = strategy.get("ratio")
        if not isinstance(raw_ratio, dict):
            raise ValueError("ratio 模式需传入 ratio 字段（dict）")
        # 归一 ratio 的键（兼容零宽字符/全角空格）
        normalized_ratio = {_normalize_level(k): v for k, v in raw_ratio.items()}
        result = {level: int(normalized_ratio.get(level, 0)) for level in LEVELS}
        if any(v < 0 for v in result.values()):
            raise ValueError(f"ratio 值不能为负: {result}")
        if sum(result.values()) != 100:
            raise ValueError(f"ratio 总和必须为 100，当前: {result}")
        return result
    if mode in _PRESETS:
        return dict(_PRESETS[mode])
    raise ValueError(
        f"未知 mode: {mode!r}，应为 single/ratio/exam_sprint/beginner_friendly"
    )
