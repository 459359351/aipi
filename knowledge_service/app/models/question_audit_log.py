"""
question_audit_logs 表 —— 题目审核与编辑日志
"""

from sqlalchemy import Column, BigInteger, Integer, String, Text, DateTime, func
from ..database import Base


class QuestionAuditLog(Base):
    __tablename__ = "question_audit_logs"

    id = Column(BigInteger, primary_key=True, autoincrement=True, comment="主键")
    question_type = Column(String(16), nullable=False, index=True, comment="题型: single/multiple/judge/essay")
    question_id = Column(Integer, nullable=False, index=True, comment="题目ID")
    operation = Column(String(32), nullable=False, index=True, comment="操作类型: edit/approve/tag_confirm")
    operator = Column(String(128), nullable=True, comment="操作人")
    before_payload = Column(Text, nullable=True, comment="修改前快照(JSON)")
    after_payload = Column(Text, nullable=True, comment="修改后快照(JSON)")
    remark = Column(Text, nullable=True, comment="备注")
    created_at = Column(DateTime, nullable=False, server_default=func.now(), comment="创建时间")

