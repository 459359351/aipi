"""
knowledge_tag_rel 表 —— 知识点与标签的多对多关联
"""

from sqlalchemy import Table, Column, BigInteger, ForeignKey
from ..database import Base

knowledge_tag_rel = Table(
    "knowledge_tag_rel",
    Base.metadata,
    Column(
        "knowledge_id",
        BigInteger,
        ForeignKey("knowledge_points.id", ondelete="CASCADE"),
        primary_key=True,
        comment="知识点 ID",
    ),
    Column(
        "tag_id",
        BigInteger,
        ForeignKey("tags.id", ondelete="CASCADE"),
        primary_key=True,
        comment="标签 ID",
    ),
)
