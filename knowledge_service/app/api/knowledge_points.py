"""
知识点查询 API
"""

import logging

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..security.company_scope import CompanyScope, get_company_scope
from ..schemas.knowledge_point import (
    KnowledgePointResponse,
    KnowledgePointListResponse,
)
from ..services import document_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/knowledge-points", tags=["知识点管理"])


@router.get(
    "/by-document/{document_id}",
    response_model=KnowledgePointListResponse,
    summary="获取文档关联的知识点列表",
)
async def get_knowledge_points_by_document(
    document_id: int,
    db: Session = Depends(get_db),
    scope: CompanyScope = Depends(get_company_scope),
):
    """根据文档 ID 查询其所有知识点"""
    doc = document_service.get_document_by_id(db, document_id, scope=scope)
    if not doc:
        raise HTTPException(status_code=404, detail="文档不存在")

    kps = document_service.get_knowledge_points_by_document(db, document_id)
    return KnowledgePointListResponse(
        total=len(kps),
        document_id=document_id,
        items=kps,
    )


@router.get(
    "/{kp_id}",
    response_model=KnowledgePointResponse,
    summary="查询单个知识点详情",
)
async def get_knowledge_point(
    kp_id: int,
    db: Session = Depends(get_db),
    scope: CompanyScope = Depends(get_company_scope),
):
    """根据 ID 查询单个知识点详情"""
    kp = document_service.get_knowledge_point_by_id(
        db,
        kp_id,
        scope=scope,
    )
    if not kp:
        raise HTTPException(status_code=404, detail="知识点不存在")
    return kp
