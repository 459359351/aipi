"""
user_question_behaviors 表 —— 用户做题行为（用于重排）
"""

from sqlalchemy import Column, BigInteger, Integer, String, SmallInteger, DateTime, func
from ..database import Base


class UserQuestionBehavior(Base):
    __tablename__ = "user_question_behaviors"

    id = Column(BigInteger, primary_key=True, autoincrement=True, comment="主键")
    user_id = Column(String(64), nullable=False, index=True, comment="用户ID")
    question_type = Column(String(16), nullable=False, index=True, comment="题型")
    question_id = Column(Integer, nullable=False, index=True, comment="题目ID")
    is_correct = Column(SmallInteger, nullable=False, default=0, comment="是否答对: 0否 1是")
    time_spent_sec = Column(Integer, nullable=False, default=0, comment="耗时秒")
    answered_at = Column(DateTime, nullable=False, server_default=func.now(), index=True, comment="作答时间")

