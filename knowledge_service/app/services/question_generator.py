"""
LLM 出题服务 —— 基于知识点文本，调用 Qwen 生成各题型的结构化题目
复用 knowledge_extractor 中的 LLM 调用模式和 JSON 容错解析。
"""

import json
import logging
import re
import time
from typing import List, Dict, Any

import dashscope
from dashscope import MultiModalConversation
from http import HTTPStatus
from json_repair import repair_json

from ..config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

dashscope.api_key = settings.DASHSCOPE_API_KEY
dashscope.base_http_api_url = "https://dashscope.aliyuncs.com/api/v1"


# ── JSON 工具函数（复用自 knowledge_extractor）──────────────

def _extract_json_from_response(text: str) -> str:
    match = re.search(r"```(?:json)?\s*\n?(.*?)\n?\s*```", text, re.DOTALL)
    if match:
        return match.group(1).strip()
    match = re.search(r"\[.*\]", text, re.DOTALL)
    if match:
        return match.group(0).strip()
    return text.strip()


def _safe_json_loads(json_str: str) -> list:
    try:
        return json.loads(json_str)
    except json.JSONDecodeError as e:
        start = max(0, e.pos - 200)
        end = min(len(json_str), e.pos + 200)
        logger.warning(
            f"[出题LLM] JSON 标准解析失败 (line {e.lineno}, col {e.colno}):\n"
            f"  错误: {e.msg}\n  上下文: ...{json_str[start:end]}..."
        )
        logger.info("[出题LLM] 尝试 json_repair 容错修复...")
        repaired = repair_json(json_str, return_objects=True)
        if isinstance(repaired, list):
            logger.info(f"[出题LLM] json_repair 修复成功，得到 {len(repaired)} 条")
            return repaired
        raise ValueError(f"LLM 返回内容无法解析为 JSON: {e}")


def _call_llm(system_text: str, user_text: str) -> str:
    """统一 LLM 调用入口，返回文本内容"""
    messages = [
        {"role": "system", "content": [{"text": system_text}]},
        {"role": "user", "content": [{"text": user_text}]},
    ]
    logger.info(f"[出题LLM] 调用 {settings.LLM_MODEL}，prompt 长度 {len(user_text)} 字符...")
    t0 = time.time()
    response = MultiModalConversation.call(
        model=settings.LLM_MODEL,
        messages=messages,
    )
    elapsed = time.time() - t0
    logger.info(f"[出题LLM] 响应完成，耗时 {elapsed:.1f}s，status={response.status_code}")

    if response.status_code != HTTPStatus.OK:
        raise ValueError(
            f"LLM 调用失败: status={response.status_code}, "
            f"code={response.code}, message={response.message}"
        )

    raw = response.output.choices[0].message.content[0]["text"]
    logger.info(f"[出题LLM] 原始响应长度: {len(raw)} 字符")
    return raw


SYSTEM_PROMPT = (
    "你是一个企业党建领域的考试命题专家，专门根据党建知识点生成高质量的考试题目。"
    "你只输出 JSON 格式内容，不输出任何解释性文字。"
    "所有 JSON 字符串值中如包含 ASCII 双引号(\")，须改用中文直角引号「」替代。"
)


# ══════════════════════════════════════════════════════════
# 单选题
# ══════════════════════════════════════════════════════════

SINGLE_CHOICE_PROMPT = """请根据以下党建知识点内容，生成 {count} 道单选题。

## 要求
1. 每道题有且仅有 4 个选项（A/B/C/D），只有一个正确答案
2. 题目应覆盖知识点中的关键信息（数字、定义、流程、职责、原则等）
3. 干扰选项应具有一定迷惑性，但不能与正确答案含义相同
4. 答案解析应简明扼要，说明为何选此项
5. source_knowledge_indices 填写本题主要依据的知识点序号（1 起始，可多个）

## 输出格式
严格以 JSON 数组返回，每个元素包含以下字段：
```json
[
  {{
    "question_text": "题目内容",
    "option_a": "选项A内容",
    "option_b": "选项B内容",
    "option_c": "选项C内容",
    "option_d": "选项D内容",
    "correct_answer": "A",
    "explanation": "答案解析",
    "source_knowledge_indices": [1]
  }}
]
```

## 知识点内容
---
{knowledge_text}
---

请生成 {count} 道单选题（仅输出 JSON 数组）："""


def generate_single_choices(knowledge_text: str, count: int) -> List[Dict[str, Any]]:
    if count <= 0:
        return []
    prompt = SINGLE_CHOICE_PROMPT.format(count=count, knowledge_text=knowledge_text)
    raw = _call_llm(SYSTEM_PROMPT, prompt)
    json_str = _extract_json_from_response(raw)
    items = _safe_json_loads(json_str)
    required = {"question_text", "option_a", "option_b", "option_c", "option_d", "correct_answer"}
    valid = [item for item in items if required.issubset(item.keys())]
    logger.info(f"[单选题] 解析成功 {len(valid)}/{len(items)} 道")
    return valid


# ══════════════════════════════════════════════════════════
# 多选题
# ══════════════════════════════════════════════════════════

MULTIPLE_CHOICE_PROMPT = """请根据以下党建知识点内容，生成 {count} 道多选题。

## 要求
1. 每道题有 {option_count} 个选项（{option_labels}），正确答案为 2 个或以上
2. 正确答案以逗号分隔的大写字母表示，如 "A,B,D"
3. 题目应覆盖知识点中需要综合理解的内容
4. 答案解析应说明每个正确选项的依据
5. source_knowledge_indices 填写本题主要依据的知识点序号（1 起始，可多个）

## 输出格式
严格以 JSON 数组返回：
```json
[
  {{
    "question_text": "题目内容",
    "option_a": "选项A内容",
    "option_b": "选项B内容",
    "option_c": "选项C内容",
    "option_d": "选项D内容",
    {option_e_field}
    "correct_answer": "A,C,D",
    "explanation": "答案解析",
    "source_knowledge_indices": [1, 3]
  }}
]
```

## 知识点内容
---
{knowledge_text}
---

请生成 {count} 道多选题（仅输出 JSON 数组）："""


def generate_multiple_choices(
    knowledge_text: str, count: int, option_count: int = 4
) -> List[Dict[str, Any]]:
    if count <= 0:
        return []
    if option_count == 5:
        option_labels = "A/B/C/D/E"
        option_e_field = '"option_e": "选项E内容",'
    else:
        option_labels = "A/B/C/D"
        option_e_field = ""

    prompt = MULTIPLE_CHOICE_PROMPT.format(
        count=count,
        option_count=option_count,
        option_labels=option_labels,
        option_e_field=option_e_field,
        knowledge_text=knowledge_text,
    )
    raw = _call_llm(SYSTEM_PROMPT, prompt)
    json_str = _extract_json_from_response(raw)
    items = _safe_json_loads(json_str)
    required = {"question_text", "option_a", "option_b", "option_c", "option_d", "correct_answer"}
    valid = [item for item in items if required.issubset(item.keys())]
    logger.info(f"[多选题] 解析成功 {len(valid)}/{len(items)} 道")
    return valid


# ══════════════════════════════════════════════════════════
# 判断题
# ══════════════════════════════════════════════════════════

JUDGE_PROMPT = """请根据以下党建知识点内容，生成 {count} 道判断题。

## 要求
1. 每道判断题的答案为正确（1）或错误（0）
2. 正确和错误的题目数量应大致均衡
3. 错误题目应基于知识点内容进行合理的细节篡改（如修改数字、调换概念、颠倒因果等）
4. 答案解析应指出错误题目的具体错误之处
5. source_knowledge_indices 填写本题主要依据的知识点序号（1 起始，可多个）

## 输出格式
严格以 JSON 数组返回：
```json
[
  {{
    "question_text": "判断题题目内容",
    "correct_answer": 1,
    "explanation": "答案解析",
    "source_knowledge_indices": [2]
  }}
]
```

## 知识点内容
---
{knowledge_text}
---

请生成 {count} 道判断题（仅输出 JSON 数组）："""


def generate_judges(knowledge_text: str, count: int) -> List[Dict[str, Any]]:
    if count <= 0:
        return []
    prompt = JUDGE_PROMPT.format(count=count, knowledge_text=knowledge_text)
    raw = _call_llm(SYSTEM_PROMPT, prompt)
    json_str = _extract_json_from_response(raw)
    items = _safe_json_loads(json_str)
    required = {"question_text", "correct_answer"}
    valid = [item for item in items if required.issubset(item.keys())]
    logger.info(f"[判断题] 解析成功 {len(valid)}/{len(items)} 道")
    return valid


# ══════════════════════════════════════════════════════════
# 简答题
# ══════════════════════════════════════════════════════════

ESSAY_PROMPT = """请根据以下党建知识点内容，生成 {count} 道简答题。

## 要求
1. **综合多知识点出题**：简答题不要求一题对应一个知识点。应优先设计需要综合多个知识点才能完整作答的题目（如概括某类制度、比较不同规定、阐述完整流程等），一道题可融合 2～5 个相关知识点；仅当某知识点本身足够独立且适合单独成题时，才用单知识点出题。
2. 题目应考查对知识点的理解、归纳和阐述能力
3. 参考答案应完整、准确，覆盖所有相关要点
4. scoring_rule 为评分得分点数组，每个得分点包含 point（要点描述）和 weight（分值权重，整数），所有 weight 之和建议为该题总分
5. 题目难度适中，既能考查记忆也能考查理解
6. source_knowledge_indices 填写本题融合的所有知识点序号（1 起始，可多个）

## 输出格式
严格以 JSON 数组返回：
```json
[
  {{
    "question_text": "简答题题目",
    "reference_answer": "完整参考答案",
    "scoring_rule": [
      {{"point": "得分要点1的描述", "weight": 2}},
      {{"point": "得分要点2的描述", "weight": 1}},
      {{"point": "得分要点3的描述", "weight": 1}}
    ],
    "source_knowledge_indices": [1, 2, 4]
  }}
]
```

## 知识点内容
---
{knowledge_text}
---

请生成 {count} 道简答题（仅输出 JSON 数组）："""


def generate_essays(knowledge_text: str, count: int) -> List[Dict[str, Any]]:
    if count <= 0:
        return []
    prompt = ESSAY_PROMPT.format(count=count, knowledge_text=knowledge_text)
    raw = _call_llm(SYSTEM_PROMPT, prompt)
    json_str = _extract_json_from_response(raw)
    items = _safe_json_loads(json_str)
    required = {"question_text", "reference_answer", "scoring_rule"}
    valid = []
    for item in items:
        if not required.issubset(item.keys()):
            continue
        if isinstance(item["scoring_rule"], list):
            item["scoring_rule"] = json.dumps(item["scoring_rule"], ensure_ascii=False)
        elif isinstance(item["scoring_rule"], str):
            pass
        else:
            item["scoring_rule"] = json.dumps(item["scoring_rule"], ensure_ascii=False)
        valid.append(item)
    logger.info(f"[简答题] 解析成功 {len(valid)}/{len(items)} 道")
    return valid
