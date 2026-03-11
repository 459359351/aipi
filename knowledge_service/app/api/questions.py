"""
AI 出题 API 端点 —— 生成题目、查询任务状态、查询已生成题目
"""

import json
import logging
import time
import hashlib
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, Query
from sqlalchemy.orm import Session

from ..database import get_db
from ..models.document import Document
from ..models.knowledge_point import KnowledgePoint
from ..models.question import (
    SingleChoice, MultipleChoice, Judge, Essay, QuestionTask,
)
from ..models.tag import Tag
from ..models.father_tag import FatherTag
from ..models.question_tag_rel import question_tag_rel
from ..models.question_audit_log import QuestionAuditLog
from sqlalchemy import select, delete, func, case
from ..services.knowledge_extractor import extract_knowledge_points_from_qa, extract_tags_from_qa_direct
from ..schemas.question import (
    QuestionGenerateRequest,
    QuestionGenerateResponse,
    QuestionTaskResponse,
    DocumentQuestionsResponse,
)
from ..tasks.question_tasks import process_question_task

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/questions", tags=["AI 出题"])

# 同题同内容的 AI 标签推荐短时缓存，避免重复等待大模型
_AI_TAG_CACHE: dict[str, dict] = {}
_AI_TAG_CACHE_TTL_SEC = 600

QUESTION_MODEL_MAP = {
    "single": SingleChoice,
    "multiple": MultipleChoice,
    "judge": Judge,
    "essay": Essay,
}


def _normalize_question_type(question_type: str) -> str:
    q_type = (question_type or "").strip().lower()
    if q_type not in QUESTION_MODEL_MAP:
        raise HTTPException(status_code=400, detail="question_type 必须是 single/multiple/judge/essay")
    return q_type


def _serialize_editable_payload(q_type: str, obj) -> dict:
    base = {
        "question_text": getattr(obj, "question_text", None),
        "explanation": getattr(obj, "explanation", None),
        "score": getattr(obj, "score", None),
        "review_status": getattr(obj, "review_status", None),
    }
    if q_type == "single":
        base.update({
            "option_a": obj.option_a,
            "option_b": obj.option_b,
            "option_c": obj.option_c,
            "option_d": obj.option_d,
            "correct_answer": obj.correct_answer,
        })
    elif q_type == "multiple":
        base.update({
            "option_a": obj.option_a,
            "option_b": obj.option_b,
            "option_c": obj.option_c,
            "option_d": obj.option_d,
            "option_e": obj.option_e,
            "correct_answer": obj.correct_answer,
        })
    elif q_type == "judge":
        base.update({"correct_answer": obj.correct_answer})
    elif q_type == "essay":
        base.update({
            "reference_answer": obj.reference_answer,
            "scoring_rule": obj.scoring_rule,
        })
    return base


def _build_qa_text_for_tag_suggest(q_type: str, obj) -> str:
    parts = [f"题型: {q_type}", f"题干: {getattr(obj, 'question_text', '') or ''}"]
    if q_type in ("single", "multiple"):
        parts.extend([
            f"A. {getattr(obj, 'option_a', '') or ''}",
            f"B. {getattr(obj, 'option_b', '') or ''}",
            f"C. {getattr(obj, 'option_c', '') or ''}",
            f"D. {getattr(obj, 'option_d', '') or ''}",
        ])
        if q_type == "multiple" and getattr(obj, "option_e", None):
            parts.append(f"E. {getattr(obj, 'option_e', '') or ''}")
        parts.append(f"答案: {getattr(obj, 'correct_answer', '') or ''}")
    elif q_type == "judge":
        parts.append(f"答案: {getattr(obj, 'correct_answer', '') or ''}")
    else:
        parts.append(f"参考答案: {getattr(obj, 'reference_answer', '') or ''}")
    if getattr(obj, "explanation", None):
        parts.append(f"解析: {obj.explanation}")
    return "\n".join(parts)


def _normalize_tag_name(name: str) -> str:
    return " ".join(str(name or "").strip().split())


def _norm_key(name: str) -> str:
    return _normalize_tag_name(name).lower()


def _find_tag_by_name(db: Session, name: str):
    normalized = _normalize_tag_name(name)
    if not normalized:
        return None
    return db.query(Tag).filter(func.lower(func.trim(Tag.tag_name)) == normalized.lower()).first()


def _compute_audit_status(review_status: int, unconfirmed_tag_count: int) -> str:
    return "passed" if int(review_status or 0) == 1 and int(unconfirmed_tag_count or 0) == 0 else "pending"


def _apply_question_edits(q_type: str, obj, body: dict) -> list[str]:
    editable_common = {"question_text", "explanation", "score", "review_status"}
    editable_map = {
        "single": editable_common | {"option_a", "option_b", "option_c", "option_d", "correct_answer"},
        "multiple": editable_common | {"option_a", "option_b", "option_c", "option_d", "option_e", "correct_answer"},
        "judge": editable_common | {"correct_answer"},
        "essay": editable_common | {"reference_answer", "scoring_rule"},
    }
    changed_fields = []
    for k, v in body.items():
        if k in editable_map[q_type]:
            setattr(obj, k, v)
            changed_fields.append(k)
    return changed_fields


def _resolve_or_create_tag(
    db: Session,
    tag_name: str,
    default_tag_type: str = "domain",
    default_tag_enabled=None,
    father_tag: str | None = None,
) -> tuple[Optional[Tag], bool, str]:
    normalized = _normalize_tag_name(tag_name)
    if not normalized:
        return None, False, ""
    tag = _find_tag_by_name(db, normalized)
    if tag:
        if father_tag and not tag.father_tag:
            tag.father_tag = father_tag
        return tag, False, normalized
    enabled = 1 if default_tag_enabled is None else (1 if int(default_tag_enabled) == 1 else 0)
    tag = Tag(tag_name=normalized, tag_type=default_tag_type or "domain", is_enabled=enabled, father_tag=father_tag)
    db.add(tag)
    db.flush()
    # 新建标签时同步更新一级标签的 sub_tag_count（支持逗号分隔多父标签）
    if father_tag:
        for ft_name in father_tag.split(","):
            ft_name = ft_name.strip()
            if not ft_name:
                continue
            ft = db.query(FatherTag).filter(FatherTag.tag_name == ft_name).first()
            if ft:
                ft.sub_tag_count = (ft.sub_tag_count or 0) + 1
    return tag, True, normalized


@router.post("/generate", response_model=QuestionGenerateResponse, summary="创建出题任务")
async def generate_questions(
    body: QuestionGenerateRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    """
    根据文档的已解析知识点，创建后台出题任务。
    返回 task_id 供后续轮询查询进度。
    """
    doc = db.query(Document).filter(Document.id == body.document_id).first()
    if not doc:
        raise HTTPException(status_code=404, detail="文档不存在")
    if doc.status != "completed":
        raise HTTPException(status_code=400, detail=f"文档尚未解析完成（当前状态: {doc.status}）")

    kp_count = (
        db.query(KnowledgePoint)
        .filter(KnowledgePoint.document_id == body.document_id)
        .count()
    )
    if kp_count == 0:
        raise HTTPException(status_code=400, detail="该文档没有已解析的知识点")

    # 单选/多选/判断：0 表示按知识点数量出题；简答题 0 表示不出
    effective_single = kp_count if body.single_choice_count <= 0 else body.single_choice_count
    effective_multiple = kp_count if body.multiple_choice_count <= 0 else body.multiple_choice_count
    effective_judge = kp_count if body.judge_count <= 0 else body.judge_count
    effective_essay = body.essay_count
    total_effective = effective_single + effective_multiple + effective_judge + effective_essay
    if total_effective == 0:
        raise HTTPException(status_code=400, detail="至少需要一种题型：填空或填 0 表示单选/多选/判断按知识点数出题")

    config = {
        "single_choice_count": body.single_choice_count,
        "multiple_choice_count": body.multiple_choice_count,
        "multiple_choice_options": body.multiple_choice_options,
        "judge_count": body.judge_count,
        "essay_count": body.essay_count,
    }

    task = QuestionTask(
        document_id=body.document_id,
        status="pending",
        config=json.dumps(config, ensure_ascii=False),
    )
    db.add(task)
    db.commit()
    db.refresh(task)

    logger.info(f"[出题] 创建任务 task_id={task.id}, document_id={body.document_id}, config={config}")

    background_tasks.add_task(
        process_question_task,
        task_id=task.id,
        document_id=body.document_id,
        config=config,
    )

    return QuestionGenerateResponse(
        task_id=task.id,
        status="pending",
        message=f"出题任务已创建，共需生成 {total_effective} 道题目（基于 {kp_count} 个知识点；0=按知识点数）",
    )


@router.get("/tasks/{task_id}", response_model=QuestionTaskResponse, summary="查询出题任务状态")
async def get_question_task(task_id: int, db: Session = Depends(get_db)):
    """根据 task_id 查询出题任务状态和结果"""
    task = db.query(QuestionTask).filter(QuestionTask.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")
    return task


@router.get("/tasks", summary="出题任务列表")
async def list_question_tasks(
    document_id: Optional[int] = Query(None, description="按文档 ID 筛选"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
):
    """分页获取出题任务列表，可按 document_id 筛选"""
    query = db.query(QuestionTask)
    if document_id is not None:
        query = query.filter(QuestionTask.document_id == document_id)
    total = query.count()
    tasks = query.order_by(QuestionTask.created_at.desc()).offset(skip).limit(limit).all()
    return {
        "total": total,
        "items": [QuestionTaskResponse.model_validate(t) for t in tasks],
    }


@router.get(
    "/by-document/{document_id}",
    response_model=DocumentQuestionsResponse,
    summary="查询文档已生成的所有题目",
)
async def get_questions_by_document(
    document_id: int,
    db: Session = Depends(get_db),
):
    """查询某文档下所有已生成的题目（按题型分类返回，含该文档下全部任务）"""
    doc = db.query(Document).filter(Document.id == document_id).first()
    if not doc:
        raise HTTPException(status_code=404, detail="文档不存在")

    single_choices = (
        db.query(SingleChoice)
        .filter(SingleChoice.document_id == document_id)
        .order_by(SingleChoice.id.desc()).all()
    )
    multiple_choices = (
        db.query(MultipleChoice)
        .filter(MultipleChoice.document_id == document_id)
        .order_by(MultipleChoice.id.desc()).all()
    )
    judges = (
        db.query(Judge)
        .filter(Judge.document_id == document_id)
        .order_by(Judge.id.desc()).all()
    )
    essays = (
        db.query(Essay)
        .filter(Essay.document_id == document_id)
        .order_by(Essay.id.desc()).all()
    )

    return DocumentQuestionsResponse(
        document_id=document_id,
        single_choices=single_choices,
        multiple_choices=multiple_choices,
        judges=judges,
        essays=essays,
    )


@router.get(
    "/by-task/{task_id}",
    response_model=DocumentQuestionsResponse,
    summary="按出题任务查询本次生成的题目",
)
async def get_questions_by_task(
    task_id: int,
    db: Session = Depends(get_db),
):
    """查询某次出题任务生成的题目（按题型分类），数量与任务 result_summary 一致"""
    task = db.query(QuestionTask).filter(QuestionTask.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")
    document_id = task.document_id

    single_choices = (
        db.query(SingleChoice)
        .filter(SingleChoice.task_id == task_id)
        .order_by(SingleChoice.id.desc()).all()
    )
    multiple_choices = (
        db.query(MultipleChoice)
        .filter(MultipleChoice.task_id == task_id)
        .order_by(MultipleChoice.id.desc()).all()
    )
    judges = (
        db.query(Judge)
        .filter(Judge.task_id == task_id)
        .order_by(Judge.id.desc()).all()
    )
    essays = (
        db.query(Essay)
        .filter(Essay.task_id == task_id)
        .order_by(Essay.id.desc()).all()
    )

    return DocumentQuestionsResponse(
        document_id=document_id,
        single_choices=single_choices,
        multiple_choices=multiple_choices,
        judges=judges,
        essays=essays,
    )


@router.get(
    "/audit/pending",
    summary="按题型获取待审核题目列表",
)
async def list_pending_audit_questions(
    question_type: str = Query(..., description="single/multiple/judge/essay"),
    keyword: Optional[str] = Query(None, description="题干关键字"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=200),
    db: Session = Depends(get_db),
):
    q_type = _normalize_question_type(question_type)
    model = QUESTION_MODEL_MAP[q_type]
    query = db.query(model).filter(model.review_status != 1)
    if keyword:
        query = query.filter(model.question_text.contains(keyword))
    total = query.count()
    rows = query.order_by(model.updated_at.desc(), model.id.desc()).offset(skip).limit(limit).all()
    question_ids = [int(r.id) for r in rows]

    rel_count_map: dict[int, dict[str, int]] = {}
    if question_ids:
        rel_rows = db.execute(
            select(
                question_tag_rel.c.question_id,
                func.sum(case((question_tag_rel.c.is_confirmed == 1, 1), else_=0)).label("confirmed"),
                func.sum(case((question_tag_rel.c.is_confirmed == 0, 1), else_=0)).label("unconfirmed"),
            )
            .where(
                (question_tag_rel.c.question_type == q_type) &
                (question_tag_rel.c.question_id.in_(question_ids))
            )
            .group_by(question_tag_rel.c.question_id)
        ).all()
        rel_count_map = {
            int(r[0]): {"confirmed": int(r[1] or 0), "unconfirmed": int(r[2] or 0)}
            for r in rel_rows
        }

    items = []
    for row in rows:
        counts = rel_count_map.get(int(row.id), {"confirmed": 0, "unconfirmed": 0})
        q_text = (row.question_text or "").replace("\n", " ").strip()
        items.append({
            "id": int(row.id),
            "question_text": row.question_text,
            "question_text_summary": q_text[:120] + ("..." if len(q_text) > 120 else ""),
            "review_status": int(getattr(row, "review_status", 0) or 0),
            "confirmed_tag_count": counts["confirmed"],
            "unconfirmed_tag_count": counts["unconfirmed"],
            "audit_status": _compute_audit_status(getattr(row, "review_status", 0), counts["unconfirmed"]),
            "created_at": str(getattr(row, "created_at", "") or ""),
            "updated_at": str(getattr(row, "updated_at", "") or ""),
        })
    return {"question_type": q_type, "total": total, "items": items}


@router.post(
    "/tags/resolve",
    summary="解析并保存单个标签（审核页手工添加）",
)
async def resolve_single_tag(
    body: dict,
    db: Session = Depends(get_db),
):
    t0 = time.time()
    tag_name = body.get("tag_name")
    default_tag_type = body.get("default_tag_type") or "domain"
    default_tag_enabled = body.get("default_tag_enabled")
    if not str(tag_name or "").strip():
        raise HTTPException(status_code=400, detail="tag_name 不能为空")

    tag, created, normalized = _resolve_or_create_tag(
        db=db,
        tag_name=tag_name,
        default_tag_type=default_tag_type,
        default_tag_enabled=default_tag_enabled,
    )
    db.commit()
    logger.info(
        "[tag_resolve] normalized=%s created=%s tag_id=%s cost_ms=%s",
        normalized,
        created,
        getattr(tag, "id", None),
        int((time.time() - t0) * 1000),
    )
    return {
        "resolved": True,
        "created": bool(created),
        "tag": {
            "id": int(tag.id),
            "tag_name": tag.tag_name,
            "tag_type": tag.tag_type,
            "is_enabled": int(tag.is_enabled or 0),
        }
    }


@router.get(
    "/{question_type}/{question_id}",
    summary="获取单题详情（审核用）",
)
async def get_question_detail(
    question_type: str,
    question_id: int,
    db: Session = Depends(get_db),
):
    q_type = _normalize_question_type(question_type)
    model = QUESTION_MODEL_MAP[q_type]
    obj = db.query(model).filter(model.id == question_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="题目不存在")

    payload = _serialize_editable_payload(q_type, obj)
    options = {}
    if q_type in ("single", "multiple"):
        options = {
            "A": payload.get("option_a") or "",
            "B": payload.get("option_b") or "",
            "C": payload.get("option_c") or "",
            "D": payload.get("option_d") or "",
        }
        if q_type == "multiple":
            options["E"] = payload.get("option_e") or ""

    row = db.execute(
        select(
            func.sum(case((question_tag_rel.c.is_confirmed == 1, 1), else_=0)).label("confirmed"),
            func.sum(case((question_tag_rel.c.is_confirmed == 0, 1), else_=0)).label("unconfirmed"),
        )
        .where(
            (question_tag_rel.c.question_type == q_type) &
            (question_tag_rel.c.question_id == question_id)
        )
    ).first()
    confirmed_cnt = int((row[0] if row else 0) or 0)
    unconfirmed_cnt = int((row[1] if row else 0) or 0)

    return {
        "question_type": q_type,
        "id": int(obj.id),
        "question_text": payload.get("question_text"),
        "options": options,
        "correct_answer": payload.get("correct_answer"),
        "reference_answer": payload.get("reference_answer"),
        "explanation": payload.get("explanation"),
        "score": payload.get("score"),
        "review_status": int(payload.get("review_status") or 0),
        "confirmed_tag_count": confirmed_cnt,
        "unconfirmed_tag_count": unconfirmed_cnt,
        "audit_status": _compute_audit_status(payload.get("review_status") or 0, unconfirmed_cnt),
    }


@router.get(
    "/{question_type}/{question_id}/tags",
    summary="查询题目标签",
)
async def get_question_tags(
    question_type: str,
    question_id: int,
    db: Session = Depends(get_db),
):
    q_type = question_type.strip().lower()
    if q_type not in ("single", "multiple", "judge", "essay"):
        raise HTTPException(status_code=400, detail="question_type 必须是 single/multiple/judge/essay")
    rows = db.execute(
        select(Tag.id, Tag.tag_name, Tag.tag_type, Tag.is_enabled, question_tag_rel.c.is_confirmed)
        .select_from(question_tag_rel.join(Tag, question_tag_rel.c.tag_id == Tag.id))
        .where((question_tag_rel.c.question_type == q_type) & (question_tag_rel.c.question_id == question_id))
        .order_by(Tag.tag_type, Tag.tag_name)
    ).all()
    return {
        "question_type": q_type,
        "question_id": question_id,
        "tags": [
            {
                "id": r[0],
                "tag_name": r[1],
                "tag_type": r[2],
                "tag_is_enabled": int(r[3] or 0),
                "is_confirmed": int(r[4] or 0),
            }
            for r in rows
        ],
    }


@router.post(
    "/{question_type}/{question_id}/tags",
    summary="为题目设置标签（覆盖写入）",
)
async def set_question_tags(
    question_type: str,
    question_id: int,
    body: dict,
    db: Session = Depends(get_db),
):
    """
    body 支持两种方式：
    - { "tag_ids": [1,2,3] }
    - { "tag_names": ["组织建设", "流程"], "default_tag_type": "domain" }
    手工设置行为视为“已确认关联”，会写入 is_confirmed=1。
    """
    q_type = question_type.strip().lower()
    if q_type not in ("single", "multiple", "judge", "essay"):
        raise HTTPException(status_code=400, detail="question_type 必须是 single/multiple/judge/essay")

    t0 = time.time()
    tag_ids = body.get("tag_ids") or []
    tag_names = body.get("tag_names") or []
    default_tag_type = body.get("default_tag_type") or ""
    default_tag_enabled = body.get("default_tag_enabled")

    resolved_ids: set[int] = set()
    normalized_names_count = 0
    existing_hit_count = 0
    created_count = 0
    norm_seen = set()
    if tag_ids:
        for tid in tag_ids:
            try:
                resolved_ids.add(int(tid))
            except Exception:
                continue
    if tag_names:
        for name in tag_names:
            normalized = _normalize_tag_name(name)
            key = _norm_key(normalized)
            if not normalized or key in norm_seen:
                continue
            norm_seen.add(key)
            normalized_names_count += 1
            # 人工新增标签默认可用；若显式 candidate 或指定 default_tag_enabled=0，则按候选处理
            enabled = default_tag_enabled
            if enabled is None and (default_tag_type or "") == "candidate":
                enabled = 0
            tag, created, _ = _resolve_or_create_tag(
                db=db,
                tag_name=normalized,
                default_tag_type=default_tag_type or "candidate",
                default_tag_enabled=enabled,
            )
            if created:
                created_count += 1
            else:
                existing_hit_count += 1
            resolved_ids.add(int(tag.id))

    # 覆盖写入
    db.execute(
        delete(question_tag_rel).where(
            (question_tag_rel.c.question_type == q_type) &
            (question_tag_rel.c.question_id == question_id)
        )
    )
    for tid in resolved_ids:
        db.execute(
            question_tag_rel.insert().values(
                question_type=q_type,
                question_id=question_id,
                tag_id=tid,
                is_confirmed=1,
            )
        )
    db.commit()
    logger.info(
        "[set_question_tags] q_type=%s q_id=%s input_ids=%s input_names=%s normalized_names=%s existing_hit=%s created=%s resolved=%s cost_ms=%s",
        q_type,
        question_id,
        len(tag_ids),
        len(tag_names),
        normalized_names_count,
        existing_hit_count,
        created_count,
        len(resolved_ids),
        int((time.time() - t0) * 1000),
    )
    return {"updated": True, "question_type": q_type, "question_id": question_id, "tag_ids": sorted(resolved_ids)}


@router.patch(
    "/{question_type}/{question_id}/tags/confirm",
    summary="批量确认/取消确认题目标签关联",
)
async def confirm_question_tags(
    question_type: str,
    question_id: int,
    body: dict,
    db: Session = Depends(get_db),
):
    q_type = question_type.strip().lower()
    if q_type not in ("single", "multiple", "judge", "essay"):
        raise HTTPException(status_code=400, detail="question_type 必须是 single/multiple/judge/essay")
    tag_ids = body.get("tag_ids") or []
    confirmed = 1 if int(body.get("confirmed", 1)) == 1 else 0
    updated = 0
    for tid in tag_ids:
        try:
            tid_int = int(tid)
        except Exception:
            continue
        res = db.execute(
            question_tag_rel.update()
            .where(
                (question_tag_rel.c.question_type == q_type) &
                (question_tag_rel.c.question_id == question_id) &
                (question_tag_rel.c.tag_id == tid_int)
            )
            .values(is_confirmed=confirmed)
        )
        updated += int(res.rowcount or 0)
    db.commit()
    return {
        "updated": updated,
        "question_type": q_type,
        "question_id": question_id,
        "confirmed": confirmed,
    }


@router.put(
    "/{question_type}/{question_id}",
    summary="编辑题目内容并一步审核生效",
)
async def edit_question(
    question_type: str,
    question_id: int,
    body: dict,
    db: Session = Depends(get_db),
):
    q_type = _normalize_question_type(question_type)
    model = QUESTION_MODEL_MAP[q_type]
    obj = db.query(model).filter(model.id == question_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="题目不存在")

    before = _serialize_editable_payload(q_type, obj)
    operator = str(body.get("operator") or "system")
    remark = body.get("remark")

    changed_fields = _apply_question_edits(q_type, obj, body)

    # 一步审核生效：若请求未显式传 review_status，默认改为通过
    if "review_status" not in body:
        obj.review_status = 1

    db.add(QuestionAuditLog(
        question_type=q_type,
        question_id=question_id,
        operation="edit",
        operator=operator,
        before_payload=json.dumps(before, ensure_ascii=False),
        after_payload=json.dumps(_serialize_editable_payload(q_type, obj), ensure_ascii=False),
        remark=remark,
    ))
    db.commit()
    return {
        "updated": True,
        "question_type": q_type,
        "question_id": question_id,
        "changed_fields": changed_fields,
        "review_status": int(getattr(obj, "review_status", 0) or 0),
    }


@router.post(
    "/{question_type}/{question_id}/audit-submit",
    summary="审核提交通过（标签确认 + 题目通过）",
)
async def audit_submit_question(
    question_type: str,
    question_id: int,
    body: dict,
    db: Session = Depends(get_db),
):
    t0 = time.time()
    q_type = _normalize_question_type(question_type)
    model = QUESTION_MODEL_MAP[q_type]
    obj = db.query(model).filter(model.id == question_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="题目不存在")

    before = _serialize_editable_payload(q_type, obj)
    operator = str(body.get("operator") or "system")
    remark = body.get("remark")

    tag_ids = body.get("tag_ids") or []
    tag_names = body.get("tag_names") or []
    default_tag_type = body.get("default_tag_type") or "domain"
    default_tag_enabled = body.get("default_tag_enabled")
    father_tag = body.get("father_tag") or None

    resolved_ids: set[int] = set()
    created_count = 0
    existing_hit_count = 0
    for tid in tag_ids:
        try:
            resolved_ids.add(int(tid))
        except Exception:
            continue

    norm_seen = set()
    for name in tag_names:
        normalized = _normalize_tag_name(name)
        key = _norm_key(normalized)
        if not normalized or key in norm_seen:
            continue
        norm_seen.add(key)
        tag, created, _ = _resolve_or_create_tag(
            db=db,
            tag_name=normalized,
            default_tag_type=default_tag_type,
            default_tag_enabled=default_tag_enabled,
            father_tag=father_tag,
        )
        if created:
            created_count += 1
        else:
            existing_hit_count += 1
        resolved_ids.add(int(tag.id))

    db.execute(
        delete(question_tag_rel).where(
            (question_tag_rel.c.question_type == q_type) &
            (question_tag_rel.c.question_id == question_id)
        )
    )
    for tid in sorted(resolved_ids):
        db.execute(
            question_tag_rel.insert().values(
                question_type=q_type,
                question_id=question_id,
                tag_id=tid,
                is_confirmed=1,
            )
        )

    changed_fields = _apply_question_edits(q_type, obj, body)
    obj.review_status = 1
    if "review_status" not in changed_fields:
        changed_fields.append("review_status")

    db.add(QuestionAuditLog(
        question_type=q_type,
        question_id=question_id,
        operation="audit_submit",
        operator=operator,
        before_payload=json.dumps(before, ensure_ascii=False),
        after_payload=json.dumps(_serialize_editable_payload(q_type, obj), ensure_ascii=False),
        remark=remark,
    ))
    db.commit()
    logger.info(
        "[audit_submit] q_type=%s q_id=%s input_ids=%s input_names=%s resolved=%s created=%s existing_hit=%s changed_fields=%s review_status=%s cost_ms=%s",
        q_type,
        question_id,
        len(tag_ids),
        len(tag_names),
        len(resolved_ids),
        created_count,
        existing_hit_count,
        ",".join(changed_fields),
        int(getattr(obj, "review_status", 0) or 0),
        int((time.time() - t0) * 1000),
    )

    return {
        "updated": True,
        "question_type": q_type,
        "question_id": question_id,
        "tag_count": len(resolved_ids),
        "changed_fields": changed_fields,
        "review_status": int(getattr(obj, "review_status", 0) or 0),
        "audit_status": "passed",
    }


@router.post(
    "/{question_type}/{question_id}/ai-tag-suggest",
    summary="对单题触发 AI 标签推荐",
)
async def ai_tag_suggest_for_question(
    question_type: str,
    question_id: int,
    body: dict = None,
    db: Session = Depends(get_db),
):
    t0 = time.time()
    q_type = _normalize_question_type(question_type)
    model = QUESTION_MODEL_MAP[q_type]
    obj = db.query(model).filter(model.id == question_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="题目不存在")
    logger.info("[ai_tag_suggest:start] q_type=%s q_id=%s", q_type, question_id)

    qa_text = _build_qa_text_for_tag_suggest(q_type, obj)
    qa_hash = hashlib.sha256(qa_text.encode("utf-8")).hexdigest()
    cache_key = f"{q_type}:{question_id}:{qa_hash}"
    cached = _AI_TAG_CACHE.get(cache_key)
    if cached and (time.time() - float(cached.get("ts", 0))) <= _AI_TAG_CACHE_TTL_SEC:
        return {
            "question_type": q_type,
            "question_id": question_id,
            "recommended_tags": list(cached.get("recommended_tags", [])),
            "suggested_tags": list(cached.get("recommended_tags", [])),
            "new_tag_candidates": [],
            "auto_applied_count": 0,
            "created_candidate_tags": 0,
            "cache_hit": True,
        }
    recommended = extract_tags_from_qa_direct(qa_text, max_tags=5)
    if not recommended:
        logger.info(
            "[ai_tag_suggest:done] q_type=%s q_id=%s extracted=0 recommended=0 cost_ms=%s",
            q_type,
            question_id,
            int((time.time() - t0) * 1000),
        )
        return {
            "question_type": q_type,
            "question_id": question_id,
            "recommended_tags": [],
            "suggested_tags": [],
            "new_tag_candidates": [],
        }

    # 可选自动应用（仅创建未确认关联，最终由审核员确认）
    auto_apply = bool((body or {}).get("auto_apply"))
    applied = 0
    if auto_apply and recommended:
        existing_ids = set(
            r[0] for r in db.execute(
                select(Tag.id).where(Tag.tag_name.in_(recommended))
            ).all()
        )
        for tid in existing_ids:
            db.execute(
                question_tag_rel.insert().prefix_with("IGNORE").values(
                    question_type=q_type,
                    question_id=question_id,
                    tag_id=int(tid),
                    is_confirmed=0,
                )
            )
            applied += 1
        db.commit()

    # 兼容字段保留：推荐标签统一放 suggested_tags，候选为空
    created_candidates = 0
    logger.info(
        "[ai_tag_suggest:done] q_type=%s q_id=%s recommended=%s auto_applied=%s cost_ms=%s",
        q_type,
        question_id,
        len(recommended),
        applied,
        int((time.time() - t0) * 1000),
    )
    _AI_TAG_CACHE[cache_key] = {
        "ts": time.time(),
        "recommended_tags": list(recommended),
    }

    return {
        "question_type": q_type,
        "question_id": question_id,
        "recommended_tags": recommended,
        "suggested_tags": recommended,
        "new_tag_candidates": [],
        "auto_applied_count": applied,
        "created_candidate_tags": created_candidates,
        "cache_hit": False,
    }


@router.post(
    "/batch/ai-tag-suggest",
    summary="批量 AI 标签推荐（常用于人工题导入后）",
)
async def batch_ai_tag_suggest(
    body: dict,
    db: Session = Depends(get_db),
):
    q_type = _normalize_question_type(body.get("question_type"))
    limit = max(1, min(int(body.get("limit", 50) or 50), 200))
    only_manual = bool(body.get("only_manual", True))
    auto_apply = bool(body.get("auto_apply", False))
    model = QUESTION_MODEL_MAP[q_type]

    query = db.query(model)
    if only_manual:
        query = query.filter(model.document_id.is_(None))
    rows = query.order_by(model.id.desc()).limit(limit).all()

    ok = 0
    failed = 0
    details = []
    for row in rows:
        try:
            res = await ai_tag_suggest_for_question(
                question_type=q_type,
                question_id=int(row.id),
                body={"auto_apply": auto_apply},
                db=db,
            )
            ok += 1
            details.append({"question_id": int(row.id), "suggested": len(res.get("suggested_tags", []))})
        except Exception:
            failed += 1
    return {"question_type": q_type, "processed": len(rows), "ok": ok, "failed": failed, "details": details}
