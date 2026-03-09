"""
question_knowledge_rel 表 —— 题目与知识点关联（用于错题推荐/文档推荐）
"""

from sqlalchemy import (
    Column, BigInteger, Integer, String, SmallInteger, DateTime, ForeignKey, func,
)
from ..database import Base


class QuestionKnowledgeRel(Base):
    __tablename__ = "question_knowledge_rel"
    __table_args__ = {"extend_existing": True}

    id = Column(BigInteger, primary_key=True, autoincrement=True, comment="主键")
    question_type = Column(
        String(16), nullable=False, index=True,
        comment="题型: single/multiple/judge/essay",
    )
    question_id = Column(
        Integer, nullable=False, index=True,
        comment="题目ID（指向对应 tb_* 表主键）",
    )
    knowledge_id = Column(
        BigInteger,
        ForeignKey("knowledge_points.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="关联知识点ID",
    )
    weight = Column(
        SmallInteger, nullable=False, default=1,
        comment="关联权重（1~3，可选）",
    )
    created_at = Column(
        DateTime, nullable=False, server_default=func.now(), comment="创建时间",
    )

    def __repr__(self) -> str:
        return (
            f"<QuestionKnowledgeRel(id={self.id}, question_type='{self.question_type}', "
            f"question_id={self.question_id}, knowledge_id={self.knowledge_id})>"
        )

