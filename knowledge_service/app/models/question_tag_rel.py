"""
question_tag_rel 表 —— 题目与标签关联
"""

from sqlalchemy import (
    Table, Column, Integer, BigInteger, String, SmallInteger, ForeignKey, UniqueConstraint,
)
from ..database import Base


question_tag_rel = Table(
    "question_tag_rel",
    Base.metadata,
    Column("id", BigInteger, primary_key=True, autoincrement=True, comment="主键"),
    Column("question_type", String(16), nullable=False, index=True, comment="题型: single/multiple/judge/essay"),
    Column("question_id", Integer, nullable=False, index=True, comment="题目ID（对应 tb_* 主键）"),
    Column("tag_id", BigInteger, ForeignKey("tags.id", ondelete="CASCADE"), nullable=False, index=True, comment="标签ID"),
    Column("is_confirmed", SmallInteger, nullable=False, default=0, index=True, comment="关联是否已人工确认：0 否，1 是"),
    UniqueConstraint("question_type", "question_id", "tag_id", name="uk_question_tag_rel"),
)

