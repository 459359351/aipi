"""
KnowledgePoint & Tag Pydantic 请求 / 响应模型
"""

from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field


# ── Tag ───────────────────────────────────────────────────

class TagResponse(BaseModel):
    """标签响应"""
    id: int
    tag_name: str
    tag_type: Optional[str] = None

    model_config = {"from_attributes": True}


# ── KnowledgePoint ────────────────────────────────────────

class KnowledgePointResponse(BaseModel):
    """知识点详情响应"""
    id: int
    document_id: int
    title: str
    content: str
    summary: Optional[str] = None
    importance_score: Optional[float] = None
    dify_document_id: Optional[str] = None
    dify_sync_status: Optional[str] = None
    tags: List[TagResponse] = []
    created_at: datetime

    model_config = {"from_attributes": True}


class KnowledgePointListResponse(BaseModel):
    """知识点列表响应"""
    total: int
    document_id: int
    items: List[KnowledgePointResponse]


class KnowledgePointExtracted(BaseModel):
    """LLM 抽取的单个知识点（内部数据结构）"""
    title: str = Field(..., description="知识点标题")
    content: str = Field(..., description="知识点详细内容")
    summary: str = Field("", description="知识点摘要")
    importance_score: float = Field(0.5, ge=0.0, le=1.0, description="重要度评分")
    tags: List[str] = Field(default_factory=list, description="标签列表")
    new_tags: List[str] = Field(default_factory=list, description="候选新标签（需人工确认）")
