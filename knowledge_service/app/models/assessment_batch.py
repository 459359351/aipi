"""
assessment_batches 表 ORM 模型 —— 考核批次
"""

from sqlalchemy import Column, Integer, String, SmallInteger, DateTime, Enum, func
from ..database import Base


class AssessmentBatch(Base):
    """考核批次（MySQL assessment_batches）"""
    __tablename__ = "assessment_batches"
    __table_args__ = {"extend_existing": True}

    id = Column(Integer, primary_key=True, autoincrement=True)
    batch_name = Column(String(100), nullable=False, index=True, comment="批次名称")
    assessment_type = Column(String(20), nullable=False, index=True, comment="考核类型: 月度/季度/年度/专项")
    title = Column(String(200), nullable=False, comment="考核主题")
    start_date = Column(DateTime, nullable=False, comment="开始时间")
    end_date = Column(DateTime, nullable=False, comment="结束时间")
    bank_id_range = Column(String(255), nullable=False, default="", comment="题库ID范围")
    is_current = Column(SmallInteger, nullable=False, default=0, index=True, comment="是否当前考核: 0否 1是")
    status = Column(Enum("draft", "active", "completed", name="batch_status"), nullable=False, default="draft", index=True, comment="状态")
    created_at = Column(DateTime, server_default=func.now(), comment="创建时间")
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now(), comment="更新时间")
