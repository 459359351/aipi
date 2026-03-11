"""
user_profiles 表 —— 用户画像（用于按人推荐）
"""

from sqlalchemy import Column, BigInteger, String, Text, DateTime, func
from ..database import Base


class UserProfile(Base):
    __tablename__ = "user_profiles"

    id = Column(BigInteger, primary_key=True, autoincrement=True, comment="主键")
    user_id = Column(String(64), nullable=False, unique=True, index=True, comment="用户ID")
    department = Column(String(128), nullable=True, index=True, comment="部门")
    position = Column(String(128), nullable=True, index=True, comment="岗位")
    level = Column(String(64), nullable=True, comment="级别")
    interests = Column(Text, nullable=True, comment="兴趣标签(JSON数组)")
    created_at = Column(DateTime, nullable=False, server_default=func.now(), comment="创建时间")
    updated_at = Column(DateTime, nullable=False, server_default=func.now(), onupdate=func.now(), comment="更新时间")

