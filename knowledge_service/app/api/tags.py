"""
标签管理 API —— 预设标签的 CRUD，按 tag_type 分组查询
"""

import logging
import time
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from sqlalchemy import func

from ..database import get_db
from ..models.tag import Tag
from ..models.father_tag import FatherTag

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/tags", tags=["标签管理"])


TAG_TYPE_ENUM = {
    "domain": "业务/主题",
    "chapter": "来源章节",
    "knowledge_type": "知识类型",
    "difficulty": "难度",
    "candidate": "候选（待审核）",
}


class TagCreate(BaseModel):
    tag_name: str = Field(..., max_length=128, description="标签名称")
    tag_type: str = Field(..., max_length=64, description="标签分类")
    is_enabled: int = Field(1, ge=0, le=1, description="是否可用：0 否，1 是")
    father_tag: Optional[str] = Field(None, max_length=128, description="所属一级标签名")


class TagUpdate(BaseModel):
    tag_name: Optional[str] = Field(None, max_length=128)
    tag_type: Optional[str] = Field(None, max_length=64)
    is_enabled: Optional[int] = Field(None, ge=0, le=1)
    father_tag: Optional[str] = Field(None, max_length=128)


class TagResponse(BaseModel):
    id: int
    tag_name: str
    tag_type: Optional[str] = None
    is_enabled: int = 0
    father_tag: Optional[str] = None

    model_config = {"from_attributes": True}


@router.get("/types", summary="获取标签分类枚举")
async def get_tag_types():
    return {"types": TAG_TYPE_ENUM}


@router.get("/father-tags", summary="获取所有一级标签")
async def list_father_tags(db: Session = Depends(get_db)):
    items = db.query(FatherTag).order_by(FatherTag.tag_name).all()
    return {"items": [{"id": int(t.id), "tag_name": t.tag_name, "sub_tag_count": int(t.sub_tag_count or 0)} for t in items]}


@router.get("/sub-tags", summary="按一级标签获取可用二级标签（is_enabled=1）")
async def list_sub_tags(
    father_tag: str = Query(..., description="一级标签名"),
    db: Session = Depends(get_db),
):
    items = (
        db.query(Tag)
        .filter(func.find_in_set(father_tag, Tag.father_tag) > 0, Tag.is_enabled == 1)
        .order_by(Tag.tag_name)
        .all()
    )
    return {"father_tag": father_tag, "items": [{"id": int(t.id), "tag_name": t.tag_name} for t in items]}


@router.get("", summary="查询标签列表（可按 tag_type 筛选）")
async def list_tags(
    tag_type: Optional[str] = Query(None, description="按分类筛选"),
    is_enabled: Optional[int] = Query(None, ge=0, le=1, description="按可用状态筛选"),
    keyword: Optional[str] = Query(None, description="标签名模糊搜索"),
    skip: int = Query(0, ge=0),
    limit: int = Query(200, ge=1, le=500),
    db: Session = Depends(get_db),
):
    t0 = time.time()
    q = db.query(Tag)
    if tag_type:
        q = q.filter(Tag.tag_type == tag_type)
    if is_enabled is not None:
        q = q.filter(Tag.is_enabled == int(is_enabled))
    if keyword:
        q = q.filter(Tag.tag_name.contains(keyword))
    total = q.count()
    items = q.order_by(Tag.tag_type, Tag.tag_name).offset(skip).limit(limit).all()
    logger.info(
        "[list_tags] keyword=%s tag_type=%s is_enabled=%s total=%s returned=%s cost_ms=%s",
        (keyword or "")[:64],
        tag_type,
        is_enabled,
        total,
        len(items),
        int((time.time() - t0) * 1000),
    )
    return {"total": total, "items": [TagResponse.model_validate(t) for t in items]}


@router.get("/grouped", summary="按 tag_type 分组返回所有标签")
async def get_tags_grouped(db: Session = Depends(get_db)):
    all_tags = db.query(Tag).order_by(Tag.tag_type, Tag.tag_name).all()
    grouped: dict = {}
    for t in all_tags:
        tp = t.tag_type or "未分类"
        grouped.setdefault(tp, []).append({"id": t.id, "tag_name": t.tag_name, "is_enabled": int(t.is_enabled or 0)})
    return {"groups": grouped, "type_labels": TAG_TYPE_ENUM}


@router.post("", summary="新增标签", response_model=TagResponse)
async def create_tag(body: TagCreate, db: Session = Depends(get_db)):
    existing = db.query(Tag).filter(Tag.tag_name == body.tag_name).first()
    if existing:
        raise HTTPException(status_code=409, detail=f"标签已存在: {body.tag_name} (id={existing.id})")
    tag = Tag(tag_name=body.tag_name, tag_type=body.tag_type, is_enabled=int(body.is_enabled), father_tag=body.father_tag)
    db.add(tag)
    db.commit()
    db.refresh(tag)
    return tag


@router.put("/{tag_id}", summary="编辑标签", response_model=TagResponse)
async def update_tag(tag_id: int, body: TagUpdate, db: Session = Depends(get_db)):
    tag = db.query(Tag).filter(Tag.id == tag_id).first()
    if not tag:
        raise HTTPException(status_code=404, detail="标签不存在")
    if body.tag_name is not None:
        dup = db.query(Tag).filter(Tag.tag_name == body.tag_name, Tag.id != tag_id).first()
        if dup:
            raise HTTPException(status_code=409, detail=f"标签名重复: {body.tag_name}")
        tag.tag_name = body.tag_name
    if body.tag_type is not None:
        tag.tag_type = body.tag_type
    if body.is_enabled is not None:
        tag.is_enabled = int(body.is_enabled)
    if body.father_tag is not None:
        old_fathers = [f.strip() for f in (tag.father_tag or "").split(",") if f.strip()]
        new_fathers = [f.strip() for f in body.father_tag.split(",") if f.strip()]
        # 递减旧父标签的 sub_tag_count
        for name in old_fathers:
            if name not in new_fathers:
                ft = db.query(FatherTag).filter(FatherTag.tag_name == name).first()
                if ft and ft.sub_tag_count > 0:
                    ft.sub_tag_count -= 1
        # 递增新父标签的 sub_tag_count
        for name in new_fathers:
            if name not in old_fathers:
                ft = db.query(FatherTag).filter(FatherTag.tag_name == name).first()
                if ft:
                    ft.sub_tag_count = (ft.sub_tag_count or 0) + 1
        tag.father_tag = body.father_tag or None
    db.commit()
    db.refresh(tag)
    return tag


@router.delete("/{tag_id}", summary="删除标签")
async def delete_tag(tag_id: int, db: Session = Depends(get_db)):
    tag = db.query(Tag).filter(Tag.id == tag_id).first()
    if not tag:
        raise HTTPException(status_code=404, detail="标签不存在")
    # 递减对应一级标签的 sub_tag_count
    if tag.father_tag:
        for ft_name in tag.father_tag.split(","):
            ft_name = ft_name.strip()
            if not ft_name:
                continue
            ft = db.query(FatherTag).filter(FatherTag.tag_name == ft_name).first()
            if ft and ft.sub_tag_count > 0:
                ft.sub_tag_count -= 1
    db.delete(tag)
    db.commit()
    return {"deleted": True, "tag_id": tag_id}


@router.post("/batch", summary="批量导入预设标签")
async def batch_create_tags(
    items: list[TagCreate],
    db: Session = Depends(get_db),
):
    created = 0
    skipped = 0
    for item in items:
        existing = db.query(Tag).filter(Tag.tag_name == item.tag_name).first()
        if existing:
            if item.tag_type and existing.tag_type != item.tag_type:
                existing.tag_type = item.tag_type
            if item.father_tag and not existing.father_tag:
                existing.father_tag = item.father_tag
            # 批量导入可把候选转正
            existing.is_enabled = int(item.is_enabled)
            skipped += 1
            continue
        db.add(Tag(tag_name=item.tag_name, tag_type=item.tag_type, is_enabled=int(item.is_enabled), father_tag=item.father_tag))
        created += 1
    db.commit()
    return {"created": created, "skipped": skipped}
