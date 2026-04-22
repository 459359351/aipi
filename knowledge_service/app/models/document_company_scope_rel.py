"""
document_company_scope_rel 表 —— 文档与公司作用域多对多关联
"""

from sqlalchemy import (
    BigInteger,
    Column,
    DateTime,
    ForeignKey,
    String,
    UniqueConstraint,
    func,
)

from ..database import Base


class DocumentCompanyScopeRel(Base):
    __tablename__ = "document_company_scope_rel"

    id = Column(BigInteger, primary_key=True, autoincrement=True, comment="主键")
    document_id = Column(
        BigInteger,
        ForeignKey("documents.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="文档ID",
    )
    company_id = Column(String(128), nullable=False, index=True, comment="公司/分公司作用域ID")
    created_at = Column(
        DateTime,
        nullable=False,
        server_default=func.now(),
        comment="创建时间",
    )
    updated_at = Column(
        DateTime,
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
        comment="更新时间",
    )

    __table_args__ = (
        UniqueConstraint("document_id", "company_id", name="uk_document_company_scope_rel"),
    )

