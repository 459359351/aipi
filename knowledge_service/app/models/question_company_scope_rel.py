"""
question_company_scope_rel 表 —— 无文档题目与公司作用域多对多关联
"""

from sqlalchemy import (
    BigInteger,
    Column,
    DateTime,
    Integer,
    String,
    UniqueConstraint,
    func,
)

from ..database import Base


class QuestionCompanyScopeRel(Base):
    __tablename__ = "question_company_scope_rel"

    id = Column(BigInteger, primary_key=True, autoincrement=True, comment="主键")
    question_type = Column(String(16), nullable=False, index=True, comment="题型: single/multiple/judge/essay")
    question_id = Column(Integer, nullable=False, index=True, comment="题目ID")
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
        UniqueConstraint(
            "question_type",
            "question_id",
            "company_id",
            name="uk_question_company_scope_rel",
        ),
    )

