"""
Document Pydantic 请求 / 响应模型
"""

from datetime import date, datetime
from typing import Optional, List
from pydantic import BaseModel, Field


# ── 请求模型 ──────────────────────────────────────────────

class DocumentUploadRequest(BaseModel):
    """文档上传请求（元数据部分，文件通过 Form/File 上传）"""
    doc_name: str = Field(..., max_length=255, description="文档名称")
    doc_type: Optional[str] = Field(None, max_length=50, description="文档类型（教材/大纲/试卷/课件）")
    business_domain: Optional[str] = Field(None, max_length=128, description="业务领域")
    org_dimension: Optional[str] = Field(None, max_length=128, description="组织维度")
    version: Optional[str] = Field(None, max_length=50, description="文档版本号")
    effective_date: Optional[date] = Field(None, description="生效日期")
    security_level: Optional[str] = Field("internal", description="安全等级")
    upload_user: Optional[str] = Field(None, max_length=128, description="上传用户标识")
    target_company_ids: List[str] = Field(..., description="文档归属的公司ID列表")


class DocumentUpdateRequest(BaseModel):
    """文档元数据更新请求（所有字段可选，仅传需要修改的字段）"""
    doc_name: Optional[str] = Field(None, max_length=255, description="文档名称")
    doc_type: Optional[str] = Field(None, max_length=50, description="文档类型")
    business_domain: Optional[str] = Field(None, max_length=128, description="业务领域")
    org_dimension: Optional[str] = Field(None, max_length=128, description="组织维度")
    version: Optional[str] = Field(None, max_length=50, description="版本号")
    effective_date: Optional[date] = Field(None, description="生效日期")
    security_level: Optional[str] = Field(None, max_length=32, description="安全等级")
    target_company_ids: Optional[List[str]] = Field(None, description="显式更新文档归属公司ID列表")


# ── 响应模型 ──────────────────────────────────────────────

class TagInfo(BaseModel):
    """标签简要信息"""
    id: int
    tag_name: str


class DocumentResponse(BaseModel):
    """文档详情响应"""
    id: int
    doc_name: str
    doc_type: Optional[str] = None
    business_domain: Optional[str] = None
    org_dimension: Optional[str] = None
    version: Optional[str] = None
    effective_date: Optional[date] = None
    file_url: Optional[str] = None
    file_hash: Optional[str] = None
    file_size: Optional[int] = None
    file_format: Optional[str] = None
    status: str
    error_message: Optional[str] = None
    security_level: Optional[str] = None
    upload_user: Optional[str] = None
    upload_time: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime
    father_tags: List[TagInfo] = []
    sub_tags: List[TagInfo] = []
    company_ids: List[str] = []

    model_config = {"from_attributes": True}


class DocumentUploadResponse(BaseModel):
    """文档上传成功响应"""
    id: int
    doc_name: str
    status: str
    message: str = "文档上传成功，后台解析任务已触发"


class DocumentListResponse(BaseModel):
    """文档列表响应"""
    total: int
    items: List[DocumentResponse]
