"""
documents 表 —— 文档元数据
"""

from datetime import datetime, date
from sqlalchemy import (
    Column, BigInteger, String, Text, Date, DateTime, func,
)
from ..database import Base


class Document(Base):
    __tablename__ = "documents"

    id = Column(BigInteger, primary_key=True, autoincrement=True, comment="主键")
    doc_name = Column(String(255), nullable=False, comment="文档名称")
    doc_type = Column(String(50), nullable=True, comment="文档类型（教材/大纲/试卷/课件）")
    business_domain = Column(String(128), nullable=True, comment="业务领域（数学/语文/物理）")
    org_dimension = Column(String(128), nullable=True, comment="组织维度（学校/年级/班级）")
    version = Column(String(50), nullable=True, comment="文档版本号")
    effective_date = Column(Date, nullable=True, comment="生效日期")
    file_url = Column(String(512), nullable=True, comment="MinIO 文件访问 URL")
    file_hash = Column(String(128), nullable=True, index=True, comment="文件 SHA256 哈希")
    file_size = Column(BigInteger, nullable=True, comment="文件大小（字节）")
    file_format = Column(String(32), nullable=True, comment="文件格式（pdf/docx/txt）")
    status = Column(
        String(32), nullable=False, default="pending",
        index=True, comment="状态: pending/parsing/completed/failed",
    )
    error_message = Column(Text, nullable=True, comment="解析失败时的错误信息")
    security_level = Column(
        String(32), nullable=True, default="internal",
        comment="安全等级（public/internal/confidential）",
    )
    upload_user = Column(String(128), nullable=True, comment="上传用户标识")
    upload_time = Column(DateTime, nullable=True, comment="上传时间")
    created_at = Column(
        DateTime, nullable=False, server_default=func.now(), comment="记录创建时间",
    )
    updated_at = Column(
        DateTime, nullable=False, server_default=func.now(),
        onupdate=func.now(), comment="记录更新时间",
    )

    def __repr__(self) -> str:
        return f"<Document(id={self.id}, doc_name='{self.doc_name}', status='{self.status}')>"
