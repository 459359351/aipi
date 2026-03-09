"""
father_tags 表 —— 一级标签
"""

from sqlalchemy import Column, BigInteger, String, Integer
from ..database import Base


class FatherTag(Base):
    __tablename__ = "father_tags"

    id = Column(BigInteger, primary_key=True, autoincrement=True, comment="主键")
    tag_name = Column(
        String(128), nullable=False, unique=True, comment="一级标签名称",
    )
    sub_tag_count = Column(
        Integer, nullable=False, default=0, comment="对应的二级标签数量",
    )

    def __repr__(self) -> str:
        return f"<FatherTag(id={self.id}, tag_name='{self.tag_name}', sub_tag_count={self.sub_tag_count})>"
