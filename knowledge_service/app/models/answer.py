"""
answers 表 ORM 模型 —— 简答题答题记录
"""

from sqlalchemy import (
    Column, Integer, Text, SmallInteger, DateTime, Numeric, JSON, func,
)
from ..database import Base


class Answer(Base):
    """简答题答题记录（MySQL answers）"""
    __tablename__ = "answers"
    __table_args__ = {"extend_existing": True}

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, nullable=False, index=True, comment="用户ID")
    question_id = Column(Integer, nullable=False, index=True, comment="题目ID")
    bank_id = Column(Integer, nullable=False, default=3, index=True, comment="题库ID")
    user_answer = Column(Text, nullable=False, comment="用户答题内容")
    score = Column(Integer, nullable=False, comment="答题得分")
    analysis_status = Column(SmallInteger, nullable=False, default=0, index=True, comment="分析状态: 0待分析 1分析中 2完成 3失败")
    analysis_id = Column(Integer, nullable=True, index=True, comment="分析结果ID")
    submitted_at = Column(DateTime, server_default=func.now(), index=True, comment="提交时间")
    ai_content_score = Column(Numeric(5, 1), nullable=True, comment="内容得分")
    ai_quality_score = Column(Numeric(5, 1), nullable=True, comment="质量得分")
    ai_topic_score = Column(Numeric(5, 1), nullable=True, comment="主题得分")
    ai_final_score = Column(Integer, nullable=True, comment="最终得分")
    ai_report = Column(Text, nullable=True, comment="评分报告")
    ai_details = Column(JSON, nullable=True, comment="评分详情")
