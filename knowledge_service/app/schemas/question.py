"""
AI 出题功能 — Pydantic 请求 / 响应模型
"""

from datetime import datetime
from typing import Optional, List, Any
from pydantic import BaseModel, Field


# ── 请求模型 ──────────────────────────────────────────────

class QuestionGenerateRequest(BaseModel):
    """出题请求

    count 字段语义：
    - None（不传 / 省略）：不生成该题型
    - 0（单选/多选/判断）：按知识点数量出题
    - 0（简答）：不生成
    - >0：按指定数量出题

    difficulty_strategy 字段（每题型可独立指定）：
    - None（不传）：不约束难度，由 LLM 自定
    - dict：{"mode": "single|ratio|exam_sprint|beginner_friendly",
            "level"?: "简单|一般|困难",  # single 模式必填
            "ratio"?: {"简单": int, "一般": int, "困难": int}  # ratio 模式必填，和=100}
    """
    document_id: int = Field(..., description="文档 ID（必须是已解析完成的文档）")
    single_choice_count: Optional[int] = Field(None, ge=0, le=50, description="单选题数量，None=跳过，0=按知识点数")
    multiple_choice_count: Optional[int] = Field(None, ge=0, le=50, description="多选题数量，None=跳过，0=按知识点数")
    multiple_choice_options: int = Field(4, ge=4, le=5, description="多选题选项数(4或5)")
    judge_count: Optional[int] = Field(None, ge=0, le=50, description="判断题数量，None=跳过，0=按知识点数")
    essay_count: Optional[int] = Field(None, ge=0, le=20, description="简答题数量，None=跳过，0=不生成")
    single_choice_difficulty_strategy: Optional[dict] = Field(None, description="单选题难度策略")
    multiple_choice_difficulty_strategy: Optional[dict] = Field(None, description="多选题难度策略")
    judge_difficulty_strategy: Optional[dict] = Field(None, description="判断题难度策略")
    essay_difficulty_strategy: Optional[dict] = Field(None, description="简答题难度策略")


# ── 响应模型 ──────────────────────────────────────────────

class QuestionGenerateResponse(BaseModel):
    """出题任务创建响应"""
    task_id: int
    status: str
    message: str


class QuestionTaskResponse(BaseModel):
    """出题任务详情"""
    id: int
    document_id: int
    status: str
    config: Optional[str] = None
    result_summary: Optional[str] = None
    error_message: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class SingleChoiceResponse(BaseModel):
    """单选题响应"""
    id: int
    question_text: str
    option_a: str
    option_b: str
    option_c: str
    option_d: str
    correct_answer: str
    explanation: Optional[str] = None
    score: int
    review_status: int
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class MultipleChoiceResponse(BaseModel):
    """多选题响应"""
    id: int
    question_text: str
    option_a: str
    option_b: str
    option_c: str
    option_d: str
    option_e: Optional[str] = None
    correct_answer: str
    explanation: Optional[str] = None
    score: int
    review_status: int
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class JudgeResponse(BaseModel):
    """判断题响应"""
    id: int
    question_text: str
    correct_answer: int
    explanation: Optional[str] = None
    score: int
    review_status: int
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class EssayResponse(BaseModel):
    """简答题响应"""
    id: int
    question_text: str
    reference_answer: str
    scoring_rule: Optional[str] = None
    score: int
    review_status: int
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class DocumentQuestionsResponse(BaseModel):
    """某文档下所有已生成题目"""
    document_id: int
    single_choices: List[SingleChoiceResponse] = []
    multiple_choices: List[MultipleChoiceResponse] = []
    judges: List[JudgeResponse] = []
    essays: List[EssayResponse] = []
