"""
knowledge_points 表 —— 知识点
"""

from datetime import datetime
from sqlalchemy import (
    Column, BigInteger, String, Text, Float, DateTime, ForeignKey, func,
)
from sqlalchemy.orm import relationship
from ..database import Base
from .knowledge_tag_rel import knowledge_tag_rel


class KnowledgePoint(Base):
    __tablename__ = "knowledge_points"

    id = Column(BigInteger, primary_key=True, autoincrement=True, comment="主键")
    document_id = Column(
        BigInteger,
        ForeignKey("documents.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="关联文档 ID",
    )
    title = Column(String(255), nullable=False, comment="知识点标题")
    content = Column(Text, nullable=False, comment="知识点详细内容")
    summary = Column(Text, nullable=True, comment="知识点摘要")
    importance_score = Column(
        Float, nullable=True, default=0.0,
        comment="重要度评分（0.0~1.0，由 LLM 给出）",
    )
    dify_document_id = Column(
        String(128), nullable=True, comment="Dify 知识库中的文档 ID",
    )
    dify_sync_status = Column(
        String(32), nullable=True, default="pending",
        comment="Dify 同步状态: pending/synced/failed",
    )
    created_at = Column(
        DateTime, nullable=False, server_default=func.now(), comment="创建时间",
    )

    # ── 关系 ──────────────────────────────────────────────
    document = relationship("Document", backref="knowledge_points", lazy="joined")
    tags = relationship("Tag", secondary=knowledge_tag_rel, backref="knowledge_points", lazy="joined")

    def __repr__(self) -> str:
        return f"<KnowledgePoint(id={self.id}, title='{self.title}')>"
