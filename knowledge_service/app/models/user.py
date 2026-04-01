"""
users 表 ORM 模型 —— 系统用户
"""

from sqlalchemy import Column, Integer, String, Text, DateTime, func
from ..database import Base


class User(Base):
    """系统用户（MySQL users）"""
    __tablename__ = "users"
    __table_args__ = {"extend_existing": True}

    id = Column(Integer, primary_key=True, autoincrement=True)
    username = Column(String(50), nullable=False, unique=True, comment="用户名")
    password = Column(String(255), nullable=False, comment="密码")
    phone = Column(String(20), nullable=False, unique=True, comment="电话号码")
    name = Column(String(50), nullable=False, comment="姓名")
    unit = Column(String(100), nullable=True, comment="单位")
    position = Column(String(50), nullable=True, comment="职务")
    tags = Column(Text, nullable=True, comment="学员标签")
    role = Column(String(20), nullable=False, default="user", comment="角色")
    avatar = Column(Integer, nullable=True, comment="头像")
    created_at = Column(DateTime, server_default=func.now(), comment="创建时间")
