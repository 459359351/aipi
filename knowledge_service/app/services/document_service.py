"""
文档业务逻辑服务 —— 元数据存储、状态管理
"""

import logging
from typing import Optional, List, Tuple

from sqlalchemy.orm import Session

from ..models.document import Document
from ..models.document_tag_rel import DocumentTagRel
from ..models.father_tag import FatherTag
from ..models.knowledge_point import KnowledgePoint
from ..models.knowledge_tag_rel import knowledge_tag_rel
from ..models.tag import Tag

logger = logging.getLogger(__name__)

# 用 sentinel 区分"调用方未传"与"显式传 None（清空）"
_UNSET = object()


def create_document(db: Session, **kwargs) -> Document:
    """创建文档记录"""
    doc = Document(**kwargs)
    db.add(doc)
    db.commit()
    db.refresh(doc)
    logger.info(f"文档记录已创建: id={doc.id}, doc_name='{doc.doc_name}'")
    return doc


def get_documents_list(
    db: Session,
    skip: int = 0,
    limit: int = 50,
    status: Optional[str] = None,
) -> Tuple[List[Document], int]:
    """分页获取文档列表，可按状态筛选"""
    query = db.query(Document)
    if status:
        query = query.filter(Document.status == status)
    total = query.count()
    docs = query.order_by(Document.created_at.desc()).offset(skip).limit(limit).all()
    return docs, total


def get_document_by_id(db: Session, document_id: int) -> Optional[Document]:
    """根据 ID 查询文档"""
    return db.query(Document).filter(Document.id == document_id).first()


def update_document_status(
    db: Session,
    document_id: int,
    status: str,
    error_message=_UNSET,
) -> None:
    """更新文档状态。
    error_message=None  → 显式清空错误信息
    error_message="..." → 设置错误信息
    不传 error_message  → 保持原有值不变
    """
    doc = db.query(Document).filter(Document.id == document_id).first()
    if doc:
        doc.status = status
        if error_message is not _UNSET:
            doc.error_message = error_message
        db.commit()
        logger.info(f"文档状态已更新: id={document_id}, status='{status}'")


def update_document_file_url(db: Session, document_id: int, file_url: str) -> None:
    """更新文档的 MinIO 文件 URL"""
    doc = db.query(Document).filter(Document.id == document_id).first()
    if doc:
        doc.file_url = file_url
        db.commit()


def get_knowledge_points_by_document(
    db: Session, document_id: int
) -> List[KnowledgePoint]:
    """获取文档关联的所有知识点"""
    return (
        db.query(KnowledgePoint)
        .filter(KnowledgePoint.document_id == document_id)
        .all()
    )


def get_knowledge_point_by_id(
    db: Session, kp_id: int
) -> Optional[KnowledgePoint]:
    """根据 ID 查询单个知识点"""
    return db.query(KnowledgePoint).filter(KnowledgePoint.id == kp_id).first()


def get_or_create_tag(
    db: Session,
    tag_name: str,
    tag_type: str = "",
    is_enabled: int = 0,
) -> Tag:
    """获取或创建标签（tag_name 唯一）"""
    tag = db.query(Tag).filter(Tag.tag_name == tag_name).first()
    if not tag:
        tag = Tag(tag_name=tag_name, tag_type=tag_type, is_enabled=int(is_enabled))
        db.add(tag)
        db.flush()  # 获取 id，但不提交
    else:
        # 补全分类：允许从空/未分类 → 有分类（不覆盖已有分类）
        if tag_type and (not tag.tag_type):
            tag.tag_type = tag_type
        # 允许把候选标签转为可用（不允许自动降级）
        if int(is_enabled) == 1 and int(tag.is_enabled or 0) == 0:
            tag.is_enabled = 1
    return tag


def save_knowledge_points(
    db: Session,
    document_id: int,
    extracted_points: list,
) -> List[KnowledgePoint]:
    """
    批量保存知识点到数据库，同时处理标签关联

    Args:
        db: 数据库会话
        document_id: 文档 ID
        extracted_points: KnowledgePointExtracted 列表

    Returns:
        保存后的 KnowledgePoint ORM 对象列表
    """
    total = len(extracted_points)
    # 用于判断哪些是可用预设标签（强关联）
    all_tags = db.query(Tag).all()
    existing_tag_map = {t.tag_name: (t.tag_type or "", int(t.is_enabled or 0)) for t in all_tags}
    enabled_preset_names = {
        t.tag_name for t in all_tags
        if int(t.is_enabled or 0) == 1 and (t.tag_type or "") != "ai"
    }
    saved = []
    for i, ep in enumerate(extracted_points):
        kp = KnowledgePoint(
            document_id=document_id,
            title=ep.title,
            content=ep.content,
            summary=ep.summary,
            importance_score=ep.importance_score,
            dify_sync_status="pending",
        )
        db.add(kp)
        db.flush()

        for tag_name in ep.tags:
            name = str(tag_name).strip()
            if not name:
                continue
            # 仅将“可用预设标签”挂到知识点。非预设标签按候选处理，不自动挂接。
            if name in enabled_preset_names:
                tag_type, _ = existing_tag_map.get(name, ("", 1))
                tag = get_or_create_tag(db, tag_name=name, tag_type=tag_type, is_enabled=1)
                kp.tags.append(tag)
            else:
                get_or_create_tag(db, tag_name=name, tag_type="ai", is_enabled=0)

        # 候选新标签：只入 tags 表（tag_type=ai），不自动挂到知识点上
        for cand in getattr(ep, "new_tags", []) or []:
            cand_name = str(cand).strip()
            if not cand_name:
                continue
            get_or_create_tag(db, tag_name=cand_name, tag_type="ai", is_enabled=0)

        saved.append(kp)
        logger.info(f"[MySQL] 知识点入库 {i+1}/{total}: id={kp.id}, title='{kp.title[:30]}', tags={len(ep.tags)}个")

    db.commit()
    for kp in saved:
        db.refresh(kp)

    logger.info(f"[MySQL] 全部提交完成，共 {len(saved)} 个知识点（document_id={document_id}）")
    return saved


def clean_knowledge_points(db: Session, document_id: int) -> List[str]:
    """
    仅清理文档关联的知识点和标签关联（保留文档本体）。
    用于重新解析前的旧数据清理。

    Returns:
        被删除知识点中非空的 dify_document_id 列表（供调用方清理 Dify）
    """
    kps = get_knowledge_points_by_document(db, document_id)
    dify_ids = [kp.dify_document_id for kp in kps if kp.dify_document_id]

    kp_ids = [kp.id for kp in kps]
    if kp_ids:
        db.execute(
            knowledge_tag_rel.delete().where(
                knowledge_tag_rel.c.knowledge_id.in_(kp_ids)
            )
        )
        db.query(KnowledgePoint).filter(
            KnowledgePoint.document_id == document_id
        ).delete(synchronize_session=False)
        db.commit()

    logger.info(f"[清理] 文档旧知识点已删除: document_id={document_id}, 知识点={len(kps)}, dify_ids={len(dify_ids)}")
    return dify_ids


def delete_document(db: Session, document_id: int) -> List[str]:
    """
    删除文档及其关联的知识点和标签关联。

    Returns:
        被删除知识点中非空的 dify_document_id 列表（供调用方清理 Dify）
    """
    dify_ids = clean_knowledge_points(db, document_id)

    db.query(Document).filter(Document.id == document_id).delete(synchronize_session=False)
    db.commit()

    logger.info(f"文档已删除: id={document_id}")
    return dify_ids


def save_document_tags(
    db: Session,
    document_id: int,
    father_tag_ids: List[int],
    tag_ids: List[int],
) -> None:
    """保存文档与标签的多对多关联（先清除旧关联再写入）"""
    db.query(DocumentTagRel).filter(DocumentTagRel.document_id == document_id).delete(
        synchronize_session=False
    )
    for fid in father_tag_ids:
        db.add(DocumentTagRel(document_id=document_id, father_tag_id=fid))
    for tid in tag_ids:
        db.add(DocumentTagRel(document_id=document_id, tag_id=tid))
    db.commit()
    logger.info(
        f"文档标签关联已保存: document_id={document_id}, "
        f"father_tags={len(father_tag_ids)}, sub_tags={len(tag_ids)}"
    )


def get_document_tags(db: Session, document_id: int) -> dict:
    """获取文档关联的一级标签和二级标签"""
    rels = db.query(DocumentTagRel).filter(DocumentTagRel.document_id == document_id).all()
    father_tag_ids = [r.father_tag_id for r in rels if r.father_tag_id]
    tag_ids = [r.tag_id for r in rels if r.tag_id]

    father_tags = []
    if father_tag_ids:
        rows = db.query(FatherTag).filter(FatherTag.id.in_(father_tag_ids)).all()
        father_tags = [{"id": int(r.id), "tag_name": r.tag_name} for r in rows]

    sub_tags = []
    if tag_ids:
        rows = db.query(Tag).filter(Tag.id.in_(tag_ids)).all()
        sub_tags = [{"id": int(r.id), "tag_name": r.tag_name} for r in rows]

    return {"father_tags": father_tags, "sub_tags": sub_tags}


# 允许通过 PUT 更新的元数据字段白名单
_UPDATABLE_FIELDS = {
    "doc_name", "doc_type", "business_domain", "org_dimension",
    "version", "effective_date", "security_level",
}


def update_document_metadata(db: Session, document_id: int, **fields) -> Optional[Document]:
    """仅更新文档的描述性元数据字段"""
    doc = db.query(Document).filter(Document.id == document_id).first()
    if not doc:
        return None

    changed = False
    for key, value in fields.items():
        if key in _UPDATABLE_FIELDS and value is not _UNSET:
            setattr(doc, key, value)
            changed = True

    if changed:
        db.commit()
        db.refresh(doc)
        logger.info(f"文档元数据已更新: id={document_id}, fields={list(fields.keys())}")

    return doc
