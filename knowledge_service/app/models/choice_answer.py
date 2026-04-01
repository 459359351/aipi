"""
choice_answers 表 ORM 模型 —— 选择判断题回答（单选/多选/判断）
"""

from sqlalchemy import Column, Integer, String, SmallInteger, DateTime, func
from ..database import Base

# tinyint → string 题型映射
CHOICE_TYPE_MAP = {1: "single", 2: "multiple", 3: "judge"}


class ChoiceAnswer(Base):
    """选择判断题回答（MySQL choice_answers）"""
    __tablename__ = "choice_answers"
    __table_args__ = {"extend_existing": True}

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, nullable=False, index=True, comment="用户ID")
    question_id = Column(Integer, nullable=False, index=True, comment="题目ID")
    bank_id = Column(Integer, nullable=False, default=3, index=True, comment="题库ID")
    user_answer = Column(String(255), nullable=False, comment="用户答题内容")
    score = Column(Integer, nullable=False, comment="答题得分")
    is_correct = Column(SmallInteger, nullable=False, default=0, comment="是否正确: 0错误 1正确")
    question_type = Column(SmallInteger, nullable=False, index=True, comment="题目类型: 1单选 2多选 3判断")
    submitted_at = Column(DateTime, server_default=func.now(), index=True, comment="提交时间")
