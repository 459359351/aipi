"""
文档上传 & 状态查询 API
"""

import hashlib
import io
import json
import logging
import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, File, Form, UploadFile, HTTPException, BackgroundTasks, Query
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session
from typing import Optional, List

from ..database import get_db
from ..security.company_scope import CompanyScope, get_company_scope, validate_target_company_ids
from ..schemas.document import (
    DocumentResponse,
    DocumentListResponse,
    DocumentUpdateRequest,
    DocumentUploadResponse,
)
from ..services import document_service
from ..services.minio_service import minio_service
from ..services.dify_service import dify_service
from ..tasks.document_tasks import process_document_task
from ..config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

router = APIRouter(prefix="/documents", tags=["文档管理"])


@router.post("/upload", response_model=DocumentUploadResponse, summary="上传文档")
async def upload_document(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(..., description="上传的文件（PDF/Word/TXT）"),
    doc_name: str = Form(..., description="文档名称"),
    doc_type: Optional[str] = Form(None, description="文档类型（兼容旧字段）"),
    business_domain: Optional[str] = Form(None, description="业务领域（兼容旧字段）"),
    father_tag_ids: Optional[str] = Form(None, description="一级标签ID数组 JSON，如 [1,2]"),
    tag_ids: Optional[str] = Form(None, description="二级标签ID数组 JSON，如 [3,5]"),
    org_dimension: Optional[str] = Form(None, description="组织维度"),
    version: Optional[str] = Form(None, description="版本号"),
    effective_date: Optional[str] = Form(None, description="生效日期 (YYYY-MM-DD)"),
    security_level: Optional[str] = Form("internal", description="安全等级"),
    upload_user: Optional[str] = Form(None, description="上传用户"),
    target_company_ids: str = Form(..., description="文档归属公司ID数组 JSON，如 [\"A\",\"B\"]"),
    db: Session = Depends(get_db),
    scope: CompanyScope = Depends(get_company_scope),
):
    """
    上传文档并触发后台解析任务

    流程：
    1. 读取文件内容，计算 SHA256 哈希
    2. 保存文档元数据到 MySQL（status=pending）
    3. 上传文件到 MinIO
    4. 触发后台异步解析任务
    """
    # ── 读取文件内容 ──────────────────────────────────────
    file_content = await file.read()
    file_size = len(file_content)

    # 计算文件哈希
    file_hash = hashlib.sha256(file_content).hexdigest()

    # 确定文件格式
    original_name = file.filename or doc_name
    file_format = original_name.rsplit(".", 1)[-1].lower() if "." in original_name else "txt"
    # 生成 MinIO object key
    now = datetime.now()
    object_key = f"{now.strftime('%Y/%m')}/{uuid.uuid4().hex}_{original_name}"

    # 解析 effective_date
    parsed_effective_date = None
    if effective_date:
        try:
            parsed_effective_date = datetime.strptime(effective_date, "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(status_code=400, detail="effective_date 格式应为 YYYY-MM-DD")

    parsed_target_company_ids = validate_target_company_ids(
        scope,
        target_company_ids,
        required=True,
    )

    parsed_father_tag_ids: List[int] = []
    parsed_tag_ids: List[int] = []
    try:
        if father_tag_ids:
            parsed_father_tag_ids = json.loads(father_tag_ids)
        if tag_ids:
            parsed_tag_ids = json.loads(tag_ids)
    except (json.JSONDecodeError, TypeError):
        raise HTTPException(status_code=400, detail="father_tag_ids / tag_ids 应为 JSON 数组，如 [1,2]")

    # ── Step 1: 保存文档元数据 ────────────────────────────
    doc = document_service.create_document(
        db,
        doc_name=doc_name,
        doc_type=doc_type,
        business_domain=business_domain,
        org_dimension=org_dimension,
        version=version,
        effective_date=parsed_effective_date,
        file_hash=file_hash,
        file_size=file_size,
        file_format=file_format,
        status="pending",
        security_level=security_level,
        upload_user=upload_user,
        upload_time=now,
    )
    document_service.replace_document_company_scopes(db, doc.id, parsed_target_company_ids)

    # ── Step 1.5: 保存文档-标签多对多关联 ─────────────────
    if parsed_father_tag_ids or parsed_tag_ids:
        document_service.save_document_tags(
            db, doc.id, parsed_father_tag_ids, parsed_tag_ids
        )

    # ── Step 2: 上传文件到 MinIO ──────────────────────────
    try:
        content_type = file.content_type or "application/octet-stream"
        file_url = minio_service.upload_file(
            object_key=object_key,
            data=io.BytesIO(file_content),
            length=file_size,
            content_type=content_type,
        )
        document_service.update_document_file_url(db, doc.id, file_url)
    except Exception as e:
        document_service.update_document_status(
            db, doc.id, "failed", error_message=f"MinIO 上传失败: {e}"
        )
        raise HTTPException(status_code=500, detail=f"文件上传到 MinIO 失败: {e}")

    # ── Step 3: 触发后台解析任务 ──────────────────────────
    background_tasks.add_task(
        process_document_task,
        document_id=doc.id,
        object_key=object_key,
        file_format=file_format,
    )

    return DocumentUploadResponse(
        id=doc.id,
        doc_name=doc.doc_name,
        status=doc.status,
        message="文档上传成功，后台解析任务已触发",
    )


@router.get("", response_model=DocumentListResponse, summary="获取文档列表")
async def list_documents(
    skip: int = Query(0, ge=0, description="跳过条数"),
    limit: int = Query(50, ge=1, le=200, description="每页条数"),
    status: Optional[str] = Query(None, description="按状态筛选"),
    db: Session = Depends(get_db),
    scope: CompanyScope = Depends(get_company_scope),
):
    """分页获取文档列表，支持按状态筛选"""
    docs, total = document_service.get_documents_list(
        db,
        skip=skip,
        limit=limit,
        status=status,
        scope=scope,
    )
    items = []
    for doc in docs:
        resp = DocumentResponse.model_validate(doc)
        tags = document_service.get_document_tags(db, doc.id)
        resp.father_tags = tags["father_tags"]
        resp.sub_tags = tags["sub_tags"]
        resp.company_ids = document_service.get_document_company_ids(db, doc.id)
        items.append(resp)
    return DocumentListResponse(total=total, items=items)


@router.get("/{document_id}", response_model=DocumentResponse, summary="查询文档详情")
async def get_document(
    document_id: int,
    db: Session = Depends(get_db),
    scope: CompanyScope = Depends(get_company_scope),
):
    """根据 ID 查询文档状态与详情"""
    doc = document_service.get_document_by_id(db, document_id, scope=scope)
    if not doc:
        raise HTTPException(status_code=404, detail="文档不存在")
    resp = DocumentResponse.model_validate(doc)
    tags = document_service.get_document_tags(db, document_id)
    resp.father_tags = tags["father_tags"]
    resp.sub_tags = tags["sub_tags"]
    resp.company_ids = document_service.get_document_company_ids(db, document_id)
    return resp


@router.post("/{document_id}/reparse", response_model=DocumentUploadResponse, summary="重新解析文档")
async def reparse_document(
    document_id: int,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    scope: CompanyScope = Depends(get_company_scope),
):
    """
    重新解析文档：先清理旧知识点（MySQL + Dify），再触发新的解析任务
    """
    doc = document_service.get_document_by_id(db, document_id, scope=scope)
    if not doc:
        raise HTTPException(status_code=404, detail="文档不存在")

    if doc.status == "parsing":
        raise HTTPException(status_code=409, detail="文档正在解析中，请勿重复触发")

    if not doc.file_url:
        raise HTTPException(status_code=400, detail="文档无文件 URL，无法重新解析")

    try:
        bucket_prefix = f"/{settings.MINIO_BUCKET}/"
        object_key = doc.file_url.split(bucket_prefix, 1)[1]
    except (IndexError, AttributeError):
        raise HTTPException(status_code=400, detail="无法从 file_url 中解析 MinIO object_key")

    # ── 清理旧知识点数据 ──────────────────────────────────
    logger.info(f"[重新解析] document_id={document_id}, 开始清理旧知识点...")
    dify_ids = document_service.clean_knowledge_points(db, document_id)

    dify_ok, dify_fail = 0, 0
    for did in dify_ids:
        if dify_service.delete_document(did):
            dify_ok += 1
        else:
            dify_fail += 1
    if dify_ids:
        logger.info(f"[重新解析] Dify 旧文档清理完成: 成功={dify_ok}, 失败={dify_fail}")

    # ── 重置状态并触发新任务 ───────────────────────────────
    document_service.update_document_status(db, document_id, "pending", error_message=None)

    background_tasks.add_task(
        process_document_task,
        document_id=doc.id,
        object_key=object_key,
        file_format=doc.file_format or "txt",
    )

    return DocumentUploadResponse(
        id=doc.id,
        doc_name=doc.doc_name,
        status="pending",
        message=f"旧知识点已清理（MySQL: {len(dify_ids)} 条, Dify: 成功 {dify_ok} / 失败 {dify_fail}），重新解析任务已触发",
    )


@router.put("/{document_id}", response_model=DocumentResponse, summary="更新文档元数据")
async def update_document(
    document_id: int,
    body: DocumentUpdateRequest,
    db: Session = Depends(get_db),
    scope: CompanyScope = Depends(get_company_scope),
):
    """更新文档的描述性元数据（不涉及文件替换）"""
    doc = document_service.get_document_by_id(db, document_id, scope=scope)
    if not doc:
        raise HTTPException(status_code=404, detail="文档不存在")

    fields = body.model_dump(exclude_unset=True)
    target_company_ids = fields.pop("target_company_ids", None)
    if not fields and target_company_ids is None:
        raise HTTPException(status_code=400, detail="未提供任何需要更新的字段")

    if fields:
        document_service.update_document_metadata(db, document_id, **fields)
    if target_company_ids is not None:
        validated_company_ids = validate_target_company_ids(
            scope,
            target_company_ids,
            required=True,
        )
        document_service.replace_document_company_scopes(db, document_id, validated_company_ids)

    updated = document_service.get_document_by_id(db, document_id, scope=scope)
    if not updated:
        raise HTTPException(status_code=404, detail="文档不存在")
    response = DocumentResponse.model_validate(updated)
    tags = document_service.get_document_tags(db, document_id)
    response.father_tags = tags["father_tags"]
    response.sub_tags = tags["sub_tags"]
    response.company_ids = document_service.get_document_company_ids(db, document_id)
    return response


def _extract_object_key(file_url: str) -> str:
    """从 MinIO file_url 中提取 object_key"""
    bucket_prefix = f"/{settings.MINIO_BUCKET}/"
    return file_url.split(bucket_prefix, 1)[1]


@router.delete("/{document_id}", summary="删除文档")
async def delete_document(
    document_id: int,
    db: Session = Depends(get_db),
    scope: CompanyScope = Depends(get_company_scope),
):
    """
    级联删除文档：Dify 知识点 → MinIO 文件 → MySQL 记录
    """
    doc = document_service.get_document_by_id(db, document_id, scope=scope)
    if not doc:
        raise HTTPException(status_code=404, detail="文档不存在")

    if doc.status == "parsing":
        raise HTTPException(status_code=409, detail="文档正在解析中，请稍后再试")

    # Step 1: 收集 Dify document IDs 并逐条删除
    kps = document_service.get_knowledge_points_by_document(db, document_id)
    dify_ids = [kp.dify_document_id for kp in kps if kp.dify_document_id]
    dify_ok, dify_fail = 0, 0
    for dify_id in dify_ids:
        if dify_service.delete_document(dify_id):
            dify_ok += 1
        else:
            dify_fail += 1

    # Step 2: 删除 MinIO 文件
    minio_deleted = False
    if doc.file_url:
        try:
            object_key = _extract_object_key(doc.file_url)
            minio_service.delete_file(object_key)
            minio_deleted = True
        except Exception as e:
            logger.warning(f"MinIO 文件删除失败: {e}")

    # Step 3: 删除 MySQL 记录（含知识点和标签关联）
    document_service.delete_document(db, document_id)

    return {
        "message": "文档已删除",
        "detail": {
            "document_id": document_id,
            "knowledge_points_deleted": len(kps),
            "dify_deleted": dify_ok,
            "dify_failed": dify_fail,
            "minio_deleted": minio_deleted,
        },
    }


@router.get("/{document_id}/render-html", summary="文档 HTML 预览")
async def render_document_html(
    document_id: int,
    db: Session = Depends(get_db),
    scope: CompanyScope = Depends(get_company_scope),
):
    """
    从 MinIO 下载文档原文，转换为 HTML 返回，供审核页面 iframe 内嵌预览。
    支持 docx / txt，PDF 暂不支持在线预览。
    """
    doc = document_service.get_document_by_id(db, document_id, scope=scope)
    if not doc:
        raise HTTPException(status_code=404, detail="文档不存在")
    if not doc.file_url:
        raise HTTPException(status_code=400, detail="文档无文件 URL")

    file_format = (doc.file_format or "").lower()

    try:
        object_key = _extract_object_key(doc.file_url)
        file_bytes = minio_service.download_file(object_key)
    except Exception as e:
        logger.error(f"[render-html] MinIO 下载失败: document_id={document_id}, error={e}")
        raise HTTPException(status_code=500, detail=f"文件下载失败: {e}")

    body_html = ""
    if file_format in ("docx", "doc"):
        import mammoth
        result = mammoth.convert_to_html(io.BytesIO(file_bytes))
        body_html = result.value
    elif file_format == "txt":
        text = file_bytes.decode("utf-8", errors="replace")
        body_html = f"<pre style='white-space:pre-wrap;word-break:break-word'>{text}</pre>"
    elif file_format == "pdf":
        body_html = "<p style='color:#999;text-align:center;margin-top:40px'>PDF 文档暂不支持在线预览</p>"
    else:
        body_html = f"<p style='color:#999;text-align:center;margin-top:40px'>不支持的文件格式: {file_format}</p>"

    html = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
body {{ font-family: -apple-system, "Microsoft YaHei", sans-serif; font-size: 14px; line-height: 1.8; color: #333; padding: 20px; margin: 0; }}
table {{ border-collapse: collapse; width: 100%; margin: 12px 0; }}
td, th {{ border: 1px solid #ddd; padding: 6px 10px; text-align: left; }}
th {{ background: #f5f5f5; }}
h1 {{ font-size: 20px; }} h2 {{ font-size: 17px; }} h3 {{ font-size: 15px; }}
p {{ margin: 8px 0; }}
</style></head><body>{body_html}</body></html>"""
    return HTMLResponse(content=html)
