"""
AI 题库 ORM 模型 —— 映射已有的 ai_tb_* 表 + 新增出题任务表
新增 document_id / task_id 列用于追溯题目来源（已有表需手动执行迁移 SQL）。
"""

from sqlalchemy import (
    Column, Integer, BigInteger, String, Text, SmallInteger,
    DateTime, func,
)
from ..database import Base


class SingleChoice(Base):
    """单选题（MySQL tb_single_choices）"""
    __tablename__ = "tb_single_choices"
    __table_args__ = {"extend_existing": True}

    id = Column(Integer, primary_key=True, autoincrement=True)
    document_id = Column(BigInteger, nullable=True, index=True, comment="来源文档 ID")
    task_id = Column(BigInteger, nullable=True, index=True, comment="出题任务 ID")
    question_text = Column(Text, nullable=False, comment="题目内容")
    option_a = Column(Text, nullable=False, comment="选项A")
    option_b = Column(Text, nullable=False, comment="选项B")
    option_c = Column(Text, nullable=False, comment="选项C")
    option_d = Column(Text, nullable=False, comment="选项D")
    correct_answer = Column(String(1), nullable=False, comment="正确答案: A/B/C/D")
    explanation = Column(Text, nullable=True, comment="答案解析")
    score = Column(Integer, nullable=False, default=10, comment="题目分值")
    review_status = Column(SmallInteger, nullable=False, default=0, comment="审核状态: 0待审核 1通过 2不通过")
    is_ai_generated = Column(SmallInteger, nullable=False, default=0, comment="是否为AI生题: 0非AI 1AI生题")
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())


class MultipleChoice(Base):
    """多选题（MySQL tb_multiple_choices）"""
    __tablename__ = "tb_multiple_choices"
    __table_args__ = {"extend_existing": True}

    id = Column(Integer, primary_key=True, autoincrement=True)
    document_id = Column(BigInteger, nullable=True, index=True, comment="来源文档 ID")
    task_id = Column(BigInteger, nullable=True, index=True, comment="出题任务 ID")
    question_text = Column(Text, nullable=False, comment="题目内容")
    option_a = Column(Text, nullable=False, comment="选项A")
    option_b = Column(Text, nullable=False, comment="选项B")
    option_c = Column(Text, nullable=False, comment="选项C")
    option_d = Column(Text, nullable=False, comment="选项D")
    option_e = Column(Text, nullable=True, comment="选项E")
    correct_answer = Column(String(20), nullable=False, comment="正确答案: 如 A,B,D")
    explanation = Column(Text, nullable=True, comment="答案解析")
    score = Column(Integer, nullable=False, default=10, comment="题目分值")
    review_status = Column(SmallInteger, nullable=False, default=0, comment="审核状态: 0待审核 1通过 2不通过")
    is_ai_generated = Column(SmallInteger, nullable=False, default=0, comment="是否为AI生题: 0非AI 1AI生题")
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())


class Judge(Base):
    """判断题（MySQL tb_judges）"""
    __tablename__ = "tb_judges"
    __table_args__ = {"extend_existing": True}

    id = Column(Integer, primary_key=True, autoincrement=True)
    document_id = Column(BigInteger, nullable=True, index=True, comment="来源文档 ID")
    task_id = Column(BigInteger, nullable=True, index=True, comment="出题任务 ID")
    question_text = Column(Text, nullable=False, comment="题目内容")
    correct_answer = Column(SmallInteger, nullable=False, comment="正确答案: 1正确 0错误")
    explanation = Column(Text, nullable=True, comment="答案解析")
    score = Column(Integer, nullable=False, default=5, comment="题目分值")
    review_status = Column(SmallInteger, nullable=False, default=0, comment="审核状态: 0待审核 1通过 2不通过")
    is_ai_generated = Column(SmallInteger, nullable=False, default=0, comment="是否为AI生题: 0非AI 1AI生题")
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())


class Essay(Base):
    """简答题（MySQL tb_essays）"""
    __tablename__ = "tb_essays"
    __table_args__ = {"extend_existing": True}

    id = Column(Integer, primary_key=True, autoincrement=True)
    document_id = Column(BigInteger, nullable=True, index=True, comment="来源文档 ID")
    task_id = Column(BigInteger, nullable=True, index=True, comment="出题任务 ID")
    question_text = Column(Text, nullable=False, comment="题目内容")
    reference_answer = Column(Text, nullable=False, comment="参考答案")
    scoring_rule = Column(Text, nullable=True, comment="评分规则 JSON")
    score = Column(Integer, nullable=False, default=20, comment="题目分值")
    review_status = Column(SmallInteger, nullable=False, default=0, comment="审核状态: 0待审核 1通过 2不通过")
    is_ai_generated = Column(SmallInteger, nullable=False, default=0, comment="是否为AI生题: 0非AI 1AI生题")
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())


class QuestionTask(Base):
    """出题任务跟踪表（新建）"""
    __tablename__ = "question_tasks"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    document_id = Column(BigInteger, nullable=False, index=True, comment="关联文档 ID")
    status = Column(String(32), nullable=False, default="pending", comment="pending/generating/completed/failed")
    config = Column(Text, nullable=True, comment="题型数量配置 JSON")
    error_message = Column(Text, nullable=True, comment="失败错误信息")
    result_summary = Column(Text, nullable=True, comment="生成结果摘要 JSON")
    created_at = Column(DateTime, nullable=False, server_default=func.now())
    updated_at = Column(DateTime, nullable=False, server_default=func.now(), onupdate=func.now())
