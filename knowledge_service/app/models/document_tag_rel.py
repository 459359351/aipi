"""
documents_tags_rel 表 —— 文档与标签的多对多关联
"""

from sqlalchemy import (
    Column, BigInteger, DateTime, ForeignKey, CheckConstraint, Index, func,
)
from ..database import Base


class DocumentTagRel(Base):
    __tablename__ = "documents_tags_rel"

    id = Column(BigInteger, primary_key=True, autoincrement=True, comment="主键")
    document_id = Column(
        BigInteger, ForeignKey("documents.id", ondelete="CASCADE"),
        nullable=False, comment="文档ID",
    )
    father_tag_id = Column(
        BigInteger, ForeignKey("father_tags.id", ondelete="CASCADE"),
        nullable=True, comment="一级标签ID",
    )
    tag_id = Column(
        BigInteger, ForeignKey("tags.id", ondelete="CASCADE"),
        nullable=True, comment="二级标签ID",
    )
    created_at = Column(
        DateTime, nullable=False, server_default=func.now(), comment="创建时间",
    )

    __table_args__ = (
        CheckConstraint(
            "(father_tag_id IS NOT NULL AND tag_id IS NULL) "
            "OR (father_tag_id IS NULL AND tag_id IS NOT NULL)",
            name="chk_one_tag",
        ),
        Index("idx_dtr_doc", "document_id"),
        Index("idx_dtr_father_tag", "father_tag_id"),
        Index("idx_dtr_tag", "tag_id"),
    )

    def __repr__(self) -> str:
        return (
            f"<DocumentTagRel(id={self.id}, document_id={self.document_id}, "
            f"father_tag_id={self.father_tag_id}, tag_id={self.tag_id})>"
        )
