"""
题目推荐 API 的请求/响应模型
"""

from datetime import datetime
from typing import Dict, List, Optional

from pydantic import BaseModel, Field


class RecommendationQuestionItem(BaseModel):
    question_type: str = Field(..., description="题型：single/multiple/judge/essay")
    question_id: int
    document_id: Optional[int] = None
    is_ai_generated: int = 0
    question_text: str
    explanation: Optional[str] = None
    score: int = 0
    created_at: Optional[datetime] = None
    options: Optional[Dict[str, str]] = None
    correct_answer: Optional[str | int] = None
    reference_answer: Optional[str] = None
    scoring_rule: Optional[str] = None
    related_score: Optional[int] = None
    recommend_reason: Optional[str] = None


class ByDocumentRecommendationResponse(BaseModel):
    document_id: int
    include_manual: bool
    requested: Dict[str, int]
    summary: Dict[str, int]
    items: List[RecommendationQuestionItem]


class ByQuestionRecommendationResponse(BaseModel):
    base_question: RecommendationQuestionItem
    knowledge_ids: List[int] = Field(default_factory=list)
    related_questions: List[RecommendationQuestionItem]


class QuestionSetResponse(BaseModel):
    mode: str = Field(..., description="出题模式：document/interest/tags/wrong_questions")
    total: int = Field(0, description="总题数")
    counts: Dict[str, int] = Field(default_factory=dict, description="各题型数量")
    groups: Dict[str, List[RecommendationQuestionItem]] = Field(
        default_factory=dict, description="按题型分组的题目"
    )


class ByTagsRecommendationResponse(BaseModel):
    tag_ids: List[int] = Field(default_factory=list)
    requested: Dict[str, int] = Field(default_factory=dict)
    summary: Dict[str, int] = Field(default_factory=dict)
    items: List[RecommendationQuestionItem] = Field(default_factory=list)

