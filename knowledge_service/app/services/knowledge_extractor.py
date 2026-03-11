"""
LLM 知识点抽取服务 —— 调用 DashScope Qwen 从文档文本中提取结构化知识点
"""

import json
import logging
import re
import time
from typing import List, Optional, Dict, Set

import dashscope
from dashscope import MultiModalConversation
from http import HTTPStatus
from json_repair import repair_json

from ..config import get_settings
from ..schemas.knowledge_point import KnowledgePointExtracted

logger = logging.getLogger(__name__)
settings = get_settings()

# 初始化 DashScope API Key 及接入点
dashscope.api_key = settings.DASHSCOPE_API_KEY
dashscope.base_http_api_url = "https://dashscope.aliyuncs.com/api/v1"


# ── 结构化 Prompt ─────────────────────────────────────────

EXTRACTION_PROMPT_TEMPLATE = """你是一个企业党建知识抽取专家，服务于企业内部考试系统的题库建设。你的任务是从党建相关文档（规章制度、管理办法、红头文件、学习材料、会议精神、政策法规等）中，抽取出可用于出题的独立知识点。

## 抽取原则

1. **可出题性**：每个知识点应能作为考试题目的素材来源，包含明确的、可考核的信息（如定义、时间、数字、流程、职责、原则、要求等）
2. **独立完整**：每个知识点应是一个独立、自包含的知识单元，脱离上下文也能理解
3. **忠于原文**：content字段应忠实反映原文表述，不要自行发挥或添加原文没有的内容

## 粒度控制（重要）

知识点的粒度应以「一道完整考题所需的信息量」为标准。具体规则：

**应当合并为一个知识点的情况：**
- 同一条款中的并列子项（如加分项上限、减分项上限、总分范围等应合并为「评分规则」）
- 同一制度的多个构成要素（如「三会一课」的四个组成部分应合并为一个知识点）
- 同一流程的连续步骤（如入党程序中的申请→培养→考察→审批应合并为「入党程序」）
- 同一主题的正反面规定（如某项工作的「应当做什么」和「不得做什么」）

**应当拆分为多个知识点的情况：**
- 不同主题或不同制度的内容（如党费缴纳与组织生活应分开）
- 同一章节中相互独立、可分别出题的条款
- 内容过长（超过300字）且涵盖多个可独立考核主题的段落

**判断标准：** 如果两段信息在出题时通常会一起出现在同一道题的题干或选项中，就应该合并为一个知识点。

## 输出字段说明

- **title**：知识点标题，简明扼要概括核心内容（15字以内为佳）
- **content**：知识点详细内容，完整保留可出题的关键信息（数字、日期、名称、流程、条件等）。若原文含 ASCII 双引号（"），输出时须改用中文直角引号「」替代，以确保 JSON 格式合法。content 长度建议在50~300字之间
- **summary**：一句话摘要，概括知识点的核心要义
- **importance_score**：出题价值评分（0.0~1.0），评判标准：
  - 0.8~1.0：核心概念、重要原则、关键数字/时间节点、必知必会内容
  - 0.5~0.7：一般性规定、补充说明、常规要求
  - 0.0~0.4：背景描述、过渡性表述、不易出题的内容
- **tags**：标签列表（必须优先从「预设标签簇」中选择），用于分类检索，应覆盖：业务/主题、章节、知识类型、难度（如适用）
- **new_tags**：候选新标签列表（仅当预设标签不足以表达时才提供），用于后续人工审核与纳入预设标签

## 预设标签簇（必须优先使用）

系统提供一批人工预设的标签，按 tag_type 分组。你必须优先从这些标签中选择并写入 tags 字段。
如果确实缺少必要标签，可以把新增建议放到 new_tags 字段中（new_tags 里不要包含预设标签里已有的值）。

```json
{preset_tags_json}
```

## 输出格式

严格以 JSON 数组格式返回，不要包含任何其他文字：

```json
[
  {{
    "title": "考核评分规则",
    "content": "考核实行百分制，基础分为100分。加分项累计不超过20分，减分项累计不超过30分。最终得分=基础分+加分-减分，最低不低于0分。90分以上为优秀，80-89分为良好，60-79分为合格，60分以下为不合格。",
    "summary": "规定了考核的百分制评分方法、加减分上限及等级划分标准",
    "importance_score": 0.85,
    "tags": ["考核评分", "评分标准", "第X条", "考核管理", "数字"],
    "new_tags": []
  }},
  {{
    "title": "民主集中制的基本原则",
    "content": "党员个人服从党的组织，少数服从多数，下级组织服从上级组织，全党各个组织和全体党员服从党的全国代表大会和中央委员会。",
    "summary": "民主集中制中「四个服从」的核心原则",
    "importance_score": 0.95,
    "tags": ["四个服从", "民主集中制", "党章第二章", "组织建设", "核心原则"],
    "new_tags": []
  }}
]
```

## 文档内容

---
{document_text}
---

请从以上文档中抽取所有可用于考试出题的知识点，注意控制粒度，不要过于细碎（仅输出 JSON 数组）："""


def _extract_json_from_response(text: str) -> str:
    """从 LLM 响应中提取 JSON 内容（兼容 markdown 代码块包裹）"""
    # 尝试匹配 ```json ... ``` 代码块
    match = re.search(r"```(?:json)?\s*\n?(.*?)\n?\s*```", text, re.DOTALL)
    if match:
        return match.group(1).strip()
    # 尝试匹配 [ ... ] 数组
    match = re.search(r"\[.*\]", text, re.DOTALL)
    if match:
        return match.group(0).strip()
    return text.strip()


CHUNK_MAX_CHARS = 10000
CHUNK_OVERLAP_CHARS = 500


def _split_text_into_chunks(text: str, max_chars: int = CHUNK_MAX_CHARS, overlap: int = CHUNK_OVERLAP_CHARS) -> List[str]:
    """
    将长文本按自然段落边界切分为多段，每段不超过 max_chars 字符，
    相邻段之间保留 overlap 字符的重叠以减少边界割裂。
    短文本（≤ max_chars）直接返回单段。
    """
    if len(text) <= max_chars:
        return [text]

    paragraphs = re.split(r'\n{2,}', text)
    if len(paragraphs) <= 1:
        paragraphs = text.split('\n')

    chunks: List[str] = []
    current_chunk = ""

    for para in paragraphs:
        candidate = (current_chunk + "\n\n" + para) if current_chunk else para
        if len(candidate) > max_chars and current_chunk:
            chunks.append(current_chunk.strip())
            tail = current_chunk[-overlap:] if len(current_chunk) > overlap else current_chunk
            current_chunk = tail + "\n\n" + para
        else:
            current_chunk = candidate

    if current_chunk.strip():
        chunks.append(current_chunk.strip())

    # 如果某段仍超长（单段落极长），做硬切分
    final_chunks: List[str] = []
    for chunk in chunks:
        if len(chunk) <= max_chars:
            final_chunks.append(chunk)
        else:
            for i in range(0, len(chunk), max_chars - overlap):
                final_chunks.append(chunk[i:i + max_chars])

    logger.info(f"文档共 {len(text)} 字符，切分为 {len(final_chunks)} 段（每段上限 {max_chars} 字符，重叠 {overlap} 字符）")
    return final_chunks


def _deduplicate_points(points: List[KnowledgePointExtracted]) -> List[KnowledgePointExtracted]:
    """
    对多段抽取结果按 title 去重：同 title 保留 importance_score 更高的那条。
    """
    seen: dict[str, KnowledgePointExtracted] = {}
    for kp in points:
        key = kp.title.strip()
        if key not in seen or kp.importance_score > seen[key].importance_score:
            seen[key] = kp
    deduped = list(seen.values())
    if len(deduped) < len(points):
        logger.info(f"去重：{len(points)} → {len(deduped)} 个知识点（移除 {len(points) - len(deduped)} 个重复项）")
    return deduped


def _safe_json_loads(json_str: str) -> list:
    """先用标准 json.loads，失败则用 json_repair 容错修复后再解析"""
    try:
        data = json.loads(json_str)
        return data
    except json.JSONDecodeError as e:
        start = max(0, e.pos - 200)
        end = min(len(json_str), e.pos + 200)
        logger.warning(
            f"[LLM] JSON 标准解析失败 (line {e.lineno}, col {e.colno}, pos {e.pos}):\n"
            f"  错误: {e.msg}\n"
            f"  上下文: ...{json_str[start:end]}..."
        )
        logger.info("[LLM] 尝试 json_repair 容错修复...")
        repaired = repair_json(json_str, return_objects=True)
        if isinstance(repaired, list):
            logger.info(f"[LLM] json_repair 修复成功，得到 {len(repaired)} 条数据")
            return repaired
        raise ValueError(f"LLM 返回内容无法解析为 JSON（json_repair 也无法修复）: {e}")


QA_EXTRACTION_PROMPT_TEMPLATE = """你是一个企业党建考试的「知识点提炼」专家。给定一道题目（包含题干、选项、答案/解析），请提炼出 1~3 个可复用、可出题的独立知识点。

## 目标
- 让这些知识点可被用于「按错题推荐」与后续的题目生成
- 内容必须忠于题目给出的信息（答案/解析视为权威来源）

## 预设标签簇（必须优先使用）
你必须优先从以下预设标签中选择并写入 tags 字段；只有确实不足时才把新增建议放到 new_tags（new_tags 不要包含预设里已有值）。

```json
{preset_tags_json}
```

## 输出字段
严格输出 JSON 数组（不要任何额外文字），每个元素包含：
- title: 15字以内
- content: 50~300字，若包含 ASCII 双引号（\"），必须改用中文直角引号「」
- summary: 1句话
- importance_score: 0~1
- tags: 优先使用预设标签（列表）
- new_tags: 候选新标签（列表）

## 题目内容
---
{qa_text}
---
"""

QA_TAGS_PROMPT_TEMPLATE = """请从下列题目内容中提炼 1~5 个不重复标签。
只输出 JSON：{{"tags":["标签1","标签2"]}}
不要解释，不要多余字段。
题目内容：
{qa_text}
"""


def extract_knowledge_points_from_qa(
    qa_text: str,
    preset_tags: Optional[Dict[str, List[str]]] = None,
) -> List[KnowledgePointExtracted]:
    """从单道题目（题干+答案/解析）中提炼 1~3 个知识点。"""
    qa_text = (qa_text or "").strip()
    if not qa_text:
        return []

    preset_tags = preset_tags or {}
    preset_tags_json = json.dumps(preset_tags, ensure_ascii=False)
    preset_set: Set[str] = set()
    for _, names in preset_tags.items():
        preset_set.update(names or [])

    prompt = QA_EXTRACTION_PROMPT_TEMPLATE.format(
        qa_text=qa_text,
        preset_tags_json=preset_tags_json,
    )
    messages = [
        {"role": "system", "content": [{"text": "你是一个企业党建考试知识点提炼专家。你只输出 JSON 数组，不输出任何解释。"}]},
        {"role": "user", "content": [{"text": prompt}]},
    ]

    logger.info(f"[LLM][QA] 开始调用 {settings.LLM_MODEL}，输入 {len(qa_text)} 字符...")
    t0 = time.time()
    response = MultiModalConversation.call(
        model=settings.LLM_MODEL,
        messages=messages,
    )
    elapsed = time.time() - t0
    logger.info(f"[LLM][QA] 响应完成，耗时 {elapsed:.1f}s，status={response.status_code}")

    if response.status_code != HTTPStatus.OK:
        logger.error(f"[LLM][QA] 调用失败: status={response.status_code}, code={response.code}, message={response.message}")
        raise ValueError(f"LLM 调用失败: {response.message}")

    raw_content = response.output.choices[0].message.content[0]["text"]
    json_str = _extract_json_from_response(raw_content)
    data = _safe_json_loads(json_str)
    if not isinstance(data, list):
        raise ValueError("LLM 返回的不是 JSON 数组")

    out: List[KnowledgePointExtracted] = []
    for item in data:
        try:
            if isinstance(item, dict):
                item = _normalize_tags(item, preset_set)
            out.append(KnowledgePointExtracted(**item))
        except Exception as e:
            logger.warning(f"[LLM][QA] 知识点校验失败，跳过: {e}")
            continue
    return out


def extract_tags_from_qa_direct(qa_text: str, max_tags: int = 5) -> List[str]:
    """从单道题目（题干+答案/解析）直接提炼推荐标签（<=max_tags）。"""
    qa_text = (qa_text or "").strip()
    if not qa_text:
        return []
    max_tags = max(1, min(int(max_tags or 5), 10))
    total_t0 = time.time()

    prompt = QA_TAGS_PROMPT_TEMPLATE.format(qa_text=qa_text)
    messages = [
        {"role": "system", "content": [{"text": "你是一个企业党建考试标签提炼助手。你只输出 JSON。"}]},
        {"role": "user", "content": [{"text": prompt}]},
    ]

    logger.info(f"[LLM][QA_TAG] 开始调用 {settings.LLM_MODEL}，输入 {len(qa_text)} 字符...")
    t0 = time.time()
    response = MultiModalConversation.call(
        model=settings.LLM_MODEL,
        messages=messages,
    )
    elapsed = time.time() - t0
    logger.info(f"[LLM][QA_TAG] 响应完成，耗时 {elapsed:.1f}s，status={response.status_code}")

    if response.status_code != HTTPStatus.OK:
        logger.error(f"[LLM][QA_TAG] 调用失败: status={response.status_code}, code={response.code}, message={response.message}")
        raise ValueError(f"LLM 调用失败: {response.message}")

    raw_content = response.output.choices[0].message.content[0]["text"]
    parse_t0 = time.time()
    json_str = _extract_json_from_response(raw_content)
    try:
        parsed = json.loads(json_str)
    except Exception:
        repaired = repair_json(json_str, return_objects=True)
        parsed = repaired

    tags = []
    if isinstance(parsed, dict):
        tags = parsed.get("tags") or []
    elif isinstance(parsed, list):
        tags = parsed
    if not isinstance(tags, list):
        tags = [tags]

    out = []
    seen = set()
    for t in tags:
        name = str(t or "").strip()
        if not name:
            continue
        key = name.lower()
        if key in seen:
            continue
        seen.add(key)
        out.append(name)
        if len(out) >= max_tags:
            break
    return out


def _normalize_tags(
    item: dict,
    preset_set: Optional[Set[str]],
) -> dict:
    """将 LLM 产出的 tags/new_tags 做一次归一化，尽量让 tags 命中预设标签。"""
    tags = item.get("tags") or []
    new_tags = item.get("new_tags") or []

    def _to_list(x):
        if x is None:
            return []
        if isinstance(x, list):
            return x
        return [x]

    tags_list = [str(t).strip() for t in _to_list(tags) if str(t).strip()]
    new_list = [str(t).strip() for t in _to_list(new_tags) if str(t).strip()]

    if not preset_set:
        item["tags"] = tags_list
        item["new_tags"] = new_list
        return item

    matched: List[str] = []
    candidates: List[str] = []
    for t in tags_list:
        if t in preset_set:
            matched.append(t)
        else:
            candidates.append(t)
    for t in new_list:
        if t in preset_set:
            matched.append(t)
        else:
            candidates.append(t)

    # 去重保持顺序
    def _dedup(seq):
        seen = set()
        out = []
        for x in seq:
            if x not in seen:
                seen.add(x)
                out.append(x)
        return out

    item["tags"] = _dedup(matched)
    item["new_tags"] = _dedup(candidates)
    return item


def _extract_single_chunk(
    chunk_text: str,
    chunk_index: int,
    total_chunks: int,
    preset_tags: Optional[Dict[str, List[str]]] = None,
) -> List[KnowledgePointExtracted]:
    """对单段文本调用 LLM 抽取知识点并返回校验后的列表。"""
    preset_tags = preset_tags or {}
    preset_tags_json = json.dumps(preset_tags, ensure_ascii=False)
    preset_set: Set[str] = set()
    for _, names in preset_tags.items():
        preset_set.update(names or [])

    prompt = EXTRACTION_PROMPT_TEMPLATE.format(
        document_text=chunk_text,
        preset_tags_json=preset_tags_json,
    )
    messages = [
        {"role": "system", "content": [{"text": "你是一个企业党建领域的知识抽取专家，专门从党建文件中提取可用于考试出题的结构化知识点。你只输出 JSON 格式内容，不输出任何解释性文字。"}]},
        {"role": "user", "content": [{"text": prompt}]},
    ]

    chunk_label = f"[段 {chunk_index}/{total_chunks}]"
    logger.info(f"[LLM] {chunk_label} 开始调用 {settings.LLM_MODEL}，输入 {len(chunk_text)} 字符...")
    t0 = time.time()
    response = MultiModalConversation.call(
        model=settings.LLM_MODEL,
        messages=messages,
    )
    elapsed = time.time() - t0
    logger.info(f"[LLM] {chunk_label} 响应完成，耗时 {elapsed:.1f}s，status={response.status_code}")

    if response.status_code != HTTPStatus.OK:
        logger.error(f"[LLM] {chunk_label} 调用失败: status={response.status_code}, code={response.code}, message={response.message}")
        raise ValueError(f"LLM 调用失败 ({chunk_label}): {response.message}")

    raw_content = response.output.choices[0].message.content[0]["text"]
    logger.info(f"[LLM] {chunk_label} 原始响应长度: {len(raw_content)} 字符")

    json_str = _extract_json_from_response(raw_content)
    data = _safe_json_loads(json_str)

    if not isinstance(data, list):
        raise ValueError(f"LLM 返回的不是 JSON 数组 ({chunk_label})")

    logger.info(f"[LLM] {chunk_label} JSON 解析成功，包含 {len(data)} 条原始知识点")

    knowledge_points = []
    for i, item in enumerate(data):
        try:
            if isinstance(item, dict):
                item = _normalize_tags(item, preset_set)
            kp = KnowledgePointExtracted(**item)
            knowledge_points.append(kp)
        except Exception as e:
            logger.warning(f"[LLM] {chunk_label} 知识点 #{i+1} 校验失败，跳过: {e}")
            continue

    logger.info(f"[LLM] {chunk_label} 校验通过 {len(knowledge_points)}/{len(data)} 个知识点")
    return knowledge_points


def extract_knowledge_points(
    document_text: str,
    preset_tags: Optional[Dict[str, List[str]]] = None,
) -> List[KnowledgePointExtracted]:
    """
    调用 LLM 从文档文本中抽取结构化知识点。
    长文档自动按段落边界切分为多段，逐段调用 LLM，最后合并去重。

    Args:
        document_text: 文档纯文本内容

    Returns:
        KnowledgePointExtracted 列表

    Raises:
        ValueError: LLM 返回内容无法解析
    """
    if not document_text or not document_text.strip():
        logger.warning("文档文本为空，跳过知识点抽取")
        return []

    chunks = _split_text_into_chunks(document_text)
    total_chunks = len(chunks)

    if total_chunks == 1:
        logger.info(f"文档长度 {len(document_text)} 字符，无需分段，直接抽取")
    else:
        logger.info(f"文档长度 {len(document_text)} 字符，已切分为 {total_chunks} 段，将逐段调用 LLM")

    all_points: List[KnowledgePointExtracted] = []
    failed_chunks: List[int] = []

    for idx, chunk in enumerate(chunks, start=1):
        try:
            points = _extract_single_chunk(chunk, idx, total_chunks, preset_tags=preset_tags)
            all_points.extend(points)
        except Exception as e:
            logger.error(f"[LLM] 第 {idx}/{total_chunks} 段抽取失败: {e}")
            failed_chunks.append(idx)

    if failed_chunks:
        logger.warning(f"共 {len(failed_chunks)} 段抽取失败: {failed_chunks}，已跳过这些段")

    if not all_points:
        if failed_chunks:
            raise ValueError(f"所有分段均抽取失败（共 {total_chunks} 段）")
        return []

    if total_chunks > 1:
        all_points = _deduplicate_points(all_points)

    logger.info(f"[LLM] 全文抽取完成：{total_chunks} 段，最终 {len(all_points)} 个知识点")
    return all_points
