"""
tags 表 —— 标签字典
"""

from sqlalchemy import Column, BigInteger, String, SmallInteger
from ..database import Base


class Tag(Base):
    __tablename__ = "tags"

    id = Column(BigInteger, primary_key=True, autoincrement=True, comment="主键")
    tag_name = Column(
        String(128), nullable=False, unique=True, index=True, comment="标签名称",
    )
    tag_type = Column(
        String(64), nullable=True, comment="标签分类（学科/难度/章节/考点类型）",
    )
    father_tag = Column(
        String(128), nullable=True,
        comment="对应的一级标签名（多个用逗号分隔）",
    )
    is_enabled = Column(
        SmallInteger, nullable=False, default=0, index=True,
        comment="是否可用标签：0 否（候选/待审核），1 是（人工确认）",
    )

    def __repr__(self) -> str:
        return (
            f"<Tag(id={self.id}, tag_name='{self.tag_name}', "
            f"tag_type='{self.tag_type}', father_tag='{self.father_tag}', "
            f"is_enabled={self.is_enabled})>"
        )
