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
from ..security.company_scope import CompanyScope, apply_document_scope, apply_question_scope, get_company_scope
from ..services.knowledge_extractor import extract_knowledge_points_from_qa, extract_tags_from_qa_direct
from ..services import document_service
from ..services.question_scope_service import get_visible_question, update_question_company_scopes_if_needed
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
    default_tag_type: str = "human",
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
    tag = Tag(tag_name=normalized, tag_type=default_tag_type or "human", is_enabled=enabled, father_tag=father_tag)
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
    scope: CompanyScope = Depends(get_company_scope),
):
    """
    根据文档的已解析知识点，创建后台出题任务。
    返回 task_id 供后续轮询查询进度。
    """
    doc = document_service.get_document_by_id(db, body.document_id, scope=scope)
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

    # count 字段语义: None=跳过, 0=按知识点数(单选/多选/判断)或不出(简答), >0=指定数量
    # 必须先判 is None 再做数值比较，否则 None <= 0 抛 TypeError
    def _effective(count, fallback_kp):
        """计算有效数量: None→0(跳过), 0→kp_count(按知识点), >0→count"""
        if count is None:
            return 0
        return fallback_kp if count <= 0 else count

    effective_single = _effective(body.single_choice_count, kp_count)
    effective_multiple = _effective(body.multiple_choice_count, kp_count)
    effective_judge = _effective(body.judge_count, kp_count)
    # 简答题: None=跳过, 0=不出, >0=指定数量 (不走 kp_count 替代)
    effective_essay = 0 if body.essay_count is None else body.essay_count

    total_effective = effective_single + effective_multiple + effective_judge + effective_essay
    if total_effective == 0:
        raise HTTPException(status_code=400, detail="至少需要启用一种题型并设置数量（0=按知识点数出题，取消勾选=不出该题型）")

    # 构建 config dict：省略 None 值字段，task 侧 config.get() 不带默认值即可判断跳过
    config = {}
    if body.single_choice_count is not None:
        config["single_choice_count"] = body.single_choice_count
        if body.single_choice_difficulty_strategy is not None:
            config["single_choice_difficulty_strategy"] = body.single_choice_difficulty_strategy
    if body.multiple_choice_count is not None:
        config["multiple_choice_count"] = body.multiple_choice_count
        config["multiple_choice_options"] = body.multiple_choice_options
        if body.multiple_choice_difficulty_strategy is not None:
            config["multiple_choice_difficulty_strategy"] = body.multiple_choice_difficulty_strategy
    if body.judge_count is not None:
        config["judge_count"] = body.judge_count
        if body.judge_difficulty_strategy is not None:
            config["judge_difficulty_strategy"] = body.judge_difficulty_strategy
    if body.essay_count is not None:
        config["essay_count"] = body.essay_count
        if body.essay_difficulty_strategy is not None:
            config["essay_difficulty_strategy"] = body.essay_difficulty_strategy

    # 请求期快验证策略（不合法直接返回 400，而不是让后台任务在 minutes 后 fail）
    for key in (
        "single_choice_difficulty_strategy",
        "multiple_choice_difficulty_strategy",
        "judge_difficulty_strategy",
        "essay_difficulty_strategy",
    ):
        strategy = config.get(key)
        if strategy is not None:
            try:
                from ..services.difficulty_allocator import resolve_strategy
                resolve_strategy(strategy)
            except ValueError as e:
                raise HTTPException(status_code=400, detail=f"{key}: {e}")

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
async def get_question_task(
    task_id: int,
    db: Session = Depends(get_db),
    scope: CompanyScope = Depends(get_company_scope),
):
    """根据 task_id 查询出题任务状态和结果"""
    task_query = db.query(QuestionTask).join(Document, Document.id == QuestionTask.document_id)
    task_query = apply_document_scope(task_query, scope, Document.id)
    task = task_query.filter(QuestionTask.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")
    return task


@router.get("/tasks", summary="出题任务列表")
async def list_question_tasks(
    document_id: Optional[int] = Query(None, description="按文档 ID 筛选"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    scope: CompanyScope = Depends(get_company_scope),
):
    """分页获取出题任务列表，可按 document_id 筛选"""
    query = db.query(QuestionTask).join(Document, Document.id == QuestionTask.document_id)
    query = apply_document_scope(query, scope, Document.id)
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
    scope: CompanyScope = Depends(get_company_scope),
):
    """查询某文档下所有已生成的题目（按题型分类返回，含该文档下全部任务）"""
    doc = document_service.get_document_by_id(db, document_id, scope=scope)
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
    scope: CompanyScope = Depends(get_company_scope),
):
    """查询某次出题任务生成的题目（按题型分类），数量与任务 result_summary 一致"""
    task_query = db.query(QuestionTask).join(Document, Document.id == QuestionTask.document_id)
    task_query = apply_document_scope(task_query, scope, Document.id)
    task = task_query.filter(QuestionTask.id == task_id).first()
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


DIFFICULTY_FILTER_MAP = {
    "simple": "简单",
    "normal": "一般",
    "hard": "困难",
}


@router.get(
    "/audit/pending",
    summary="按题型获取待审核题目列表",
)
async def list_pending_audit_questions(
    question_type: str = Query(..., description="single/multiple/judge/essay"),
    keyword: Optional[str] = Query(None, description="题干关键字"),
    difficulty: Optional[str] = Query(
        None,
        description="难度过滤：simple/normal/hard/unlabeled/all；不传或 all 表示不过滤",
    ),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=200),
    db: Session = Depends(get_db),
    scope: CompanyScope = Depends(get_company_scope),
):
    q_type = _normalize_question_type(question_type)
    model = QUESTION_MODEL_MAP[q_type]
    query = db.query(model).filter(model.review_status != 1)
    query = apply_question_scope(query, scope, q_type, model)
    if keyword:
        query = query.filter(model.question_text.contains(keyword))

    difficulty_key = (difficulty or "").strip().lower() or "all"
    if difficulty_key != "all":
        if difficulty_key == "unlabeled":
            query = query.filter(
                ~select(question_tag_rel.c.id)
                .join(Tag, Tag.id == question_tag_rel.c.tag_id)
                .where(
                    (question_tag_rel.c.question_type == q_type)
                    & (question_tag_rel.c.question_id == model.id)
                    & (Tag.tag_type == "difficulty")
                )
                .exists()
            )
        elif difficulty_key in DIFFICULTY_FILTER_MAP:
            target_name = DIFFICULTY_FILTER_MAP[difficulty_key]
            query = query.filter(
                select(question_tag_rel.c.id)
                .join(Tag, Tag.id == question_tag_rel.c.tag_id)
                .where(
                    (question_tag_rel.c.question_type == q_type)
                    & (question_tag_rel.c.question_id == model.id)
                    & (Tag.tag_type == "difficulty")
                    & (Tag.tag_name == target_name)
                )
                .exists()
            )
        else:
            raise HTTPException(
                status_code=400,
                detail="difficulty 必须是 simple/normal/hard/unlabeled/all",
            )

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
    scope: CompanyScope = Depends(get_company_scope),
):
    t0 = time.time()
    tag_name = body.get("tag_name")
    default_tag_type = body.get("default_tag_type") or "human"
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
    scope: CompanyScope = Depends(get_company_scope),
):
    q_type = _normalize_question_type(question_type)
    obj = get_visible_question(db, scope, q_type, question_id)
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
        "document_id": getattr(obj, "document_id", None),
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
    scope: CompanyScope = Depends(get_company_scope),
):
    q_type = question_type.strip().lower()
    if q_type not in ("single", "multiple", "judge", "essay"):
        raise HTTPException(status_code=400, detail="question_type 必须是 single/multiple/judge/essay")
    obj = get_visible_question(db, scope, q_type, question_id)
    if not obj:
        raise HTTPException(status_code=404, detail="题目不存在")
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
    scope: CompanyScope = Depends(get_company_scope),
):
    """
    body 支持两种方式：
    - { "tag_ids": [1,2,3] }
    - { “tag_names”: [“组织建设”, “流程”], “default_tag_type”: “human” }
    手工设置行为视为”已确认关联”，会写入 is_confirmed=1。
    """
    q_type = question_type.strip().lower()
    if q_type not in ("single", "multiple", "judge", "essay"):
        raise HTTPException(status_code=400, detail="question_type 必须是 single/multiple/judge/essay")
    obj = get_visible_question(db, scope, q_type, question_id)
    if not obj:
        raise HTTPException(status_code=404, detail="题目不存在")

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
            # 人工新增标签默认可用；若 tag_type=ai 或指定 default_tag_enabled=0，则按候选处理
            enabled = default_tag_enabled
            if enabled is None and (default_tag_type or "") == "ai":
                enabled = 0
            tag, created, _ = _resolve_or_create_tag(
                db=db,
                tag_name=normalized,
                default_tag_type=default_tag_type or "ai",
                default_tag_enabled=enabled,
            )
            if created:
                created_count += 1
            else:
                existing_hit_count += 1
            resolved_ids.add(int(tag.id))

    # 覆盖写入普通标签，但保留难度标签；难度由 audit-submit 的 difficulty 字段维护。
    difficulty_tag_ids = {
        int(t.id) for t in db.query(Tag.id).filter(Tag.tag_type == "difficulty").all()
    }
    resolved_ids -= difficulty_tag_ids
    delete_stmt = delete(question_tag_rel).where(
        (question_tag_rel.c.question_type == q_type) &
        (question_tag_rel.c.question_id == question_id)
    )
    if difficulty_tag_ids:
        delete_stmt = delete_stmt.where(~question_tag_rel.c.tag_id.in_(difficulty_tag_ids))
    db.execute(delete_stmt)
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
    scope: CompanyScope = Depends(get_company_scope),
):
    q_type = question_type.strip().lower()
    if q_type not in ("single", "multiple", "judge", "essay"):
        raise HTTPException(status_code=400, detail="question_type 必须是 single/multiple/judge/essay")
    obj = get_visible_question(db, scope, q_type, question_id)
    if not obj:
        raise HTTPException(status_code=404, detail="题目不存在")
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
    scope: CompanyScope = Depends(get_company_scope),
):
    q_type = _normalize_question_type(question_type)
    obj = get_visible_question(db, scope, q_type, question_id)
    if not obj:
        raise HTTPException(status_code=404, detail="题目不存在")

    before = _serialize_editable_payload(q_type, obj)
    operator = str(body.get("operator") or "system")
    remark = body.get("remark")

    changed_fields = _apply_question_edits(q_type, obj, body)
    update_question_company_scopes_if_needed(
        db,
        scope,
        q_type,
        obj,
        body.get("target_company_ids"),
    )

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
    scope: CompanyScope = Depends(get_company_scope),
):
    t0 = time.time()
    q_type = _normalize_question_type(question_type)
    obj = get_visible_question(db, scope, q_type, question_id)
    if not obj:
        raise HTTPException(status_code=404, detail="题目不存在")

    before = _serialize_editable_payload(q_type, obj)
    operator = str(body.get("operator") or "system")
    remark = body.get("remark")

    tag_ids = body.get("tag_ids") or []
    ai_tag_names = body.get("ai_tag_names") or []
    human_tag_names = body.get("human_tag_names") or []
    # 兼容旧格式：如果没有分开传，则全部走 default_tag_type
    tag_names = body.get("tag_names") or []
    default_tag_type = body.get("default_tag_type") or "human"
    default_tag_enabled = body.get("default_tag_enabled")
    father_tag = body.get("father_tag") or None
    update_question_company_scopes_if_needed(
        db,
        scope,
        q_type,
        obj,
        body.get("target_company_ids"),
    )

    # 难度字段：simple/normal/hard（非空时覆盖难度标签），缺省或 null 时隐式保留并提升现有难度 rel
    difficulty_raw = body.get("difficulty")
    difficulty_key = (str(difficulty_raw).strip().lower() if difficulty_raw is not None else "")
    difficulty_tag_name: Optional[str] = None
    if difficulty_key:
        if difficulty_key not in DIFFICULTY_FILTER_MAP:
            raise HTTPException(
                status_code=400,
                detail="difficulty 必须是 simple/normal/hard",
            )
        difficulty_tag_name = DIFFICULTY_FILTER_MAP[difficulty_key]

    resolved_ids: set[int] = set()
    created_count = 0
    existing_hit_count = 0
    for tid in tag_ids:
        try:
            resolved_ids.add(int(tid))
        except Exception:
            continue

    # 收集所有 tag_type='difficulty' 的 tag_id，用于后续 scoped upsert
    all_difficulty_ids = {
        int(t.id) for t in db.query(Tag).filter(Tag.tag_type == "difficulty").all()
    }
    difficulty_action = "unchanged"
    if difficulty_tag_name is not None:
        # 显式指定：剔除 resolved_ids 里其他难度标签，确保最后只保留一条 difficulty rel
        resolved_ids -= all_difficulty_ids
        target = (
            db.query(Tag)
            .filter(Tag.tag_type == "difficulty", Tag.tag_name == difficulty_tag_name)
            .first()
        )
        if not target:
            raise HTTPException(
                status_code=500,
                detail=f"难度标签 '{difficulty_tag_name}' 未在 tags 表中预置",
            )
        resolved_ids.add(int(target.id))
        difficulty_action = f"set:{difficulty_tag_name}"
    else:
        # 未指定：先剔除 tag_ids 里误传的难度标签（保证最后只有 1 条），再保留现有 difficulty rel（含 AI 建议）
        resolved_ids -= all_difficulty_ids
        existing_diff_rows = db.execute(
            select(question_tag_rel.c.tag_id).where(
                (question_tag_rel.c.question_type == q_type)
                & (question_tag_rel.c.question_id == question_id)
                & (question_tag_rel.c.tag_id.in_(all_difficulty_ids))
            )
        ).all()
        # 若存在多条（异常态，例如并发竞争），仅保留首条，避免一题多难度
        existing_diff_ids = [int(r[0]) for r in existing_diff_rows][:1]
        if existing_diff_ids:
            resolved_ids.update(existing_diff_ids)
            difficulty_action = f"promoted:{len(existing_diff_ids)}"

    # 按来源分别处理：AI 推荐的 tag_type='ai'，人工添加的 tag_type='human'
    typed_names: list[tuple[str, str]] = []
    for name in ai_tag_names:
        typed_names.append((name, "ai"))
    for name in human_tag_names:
        typed_names.append((name, "human"))
    # 兼容旧格式（未分开传的 tag_names 走 default_tag_type）
    seen_in_typed = set(n.strip().lower() for n, _ in typed_names)
    for name in tag_names:
        if name.strip().lower() not in seen_in_typed:
            typed_names.append((name, default_tag_type))

    norm_seen = set()
    for name, tag_type_for_new in typed_names:
        normalized = _normalize_tag_name(name)
        key = _norm_key(normalized)
        if not normalized or key in norm_seen:
            continue
        norm_seen.add(key)
        tag, created, _ = _resolve_or_create_tag(
            db=db,
            tag_name=normalized,
            default_tag_type=tag_type_for_new,
            default_tag_enabled=default_tag_enabled,
            father_tag=father_tag,
        )
        if created:
            created_count += 1
        else:
            existing_hit_count += 1
            # 已有标签也更新 tag_type 为本次来源
            if tag and tag.tag_type != tag_type_for_new:
                tag.tag_type = tag_type_for_new
        resolved_ids.add(int(tag.id))

    # 审核通过的标签：确保 is_enabled=1，绑定 father_tag，更新 father_tags 表
    if resolved_ids and father_tag:
        tags_to_update = db.query(Tag).filter(Tag.id.in_(list(resolved_ids))).all()
        for tag in tags_to_update:
            tag.is_enabled = 1
            old_fathers = set(f.strip() for f in (tag.father_tag or "").split(",") if f.strip())
            new_fathers = set(f.strip() for f in father_tag.split(",") if f.strip())
            if not new_fathers.issubset(old_fathers):
                merged = old_fathers | new_fathers
                tag.father_tag = ",".join(sorted(merged))
                # 更新 father_tags 表的 sub_tag_count
                added_fathers = new_fathers - old_fathers
                for ft_name in added_fathers:
                    ft = db.query(FatherTag).filter(FatherTag.tag_name == ft_name).first()
                    if ft:
                        ft.sub_tag_count = (ft.sub_tag_count or 0) + 1
    elif resolved_ids:
        # 没有 father_tag 也要确保 is_enabled=1
        db.query(Tag).filter(Tag.id.in_(list(resolved_ids))).update(
            {Tag.is_enabled: 1}, synchronize_session=False
        )

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
        "[audit_submit] q_type=%s q_id=%s input_ids=%s input_names=%s resolved=%s created=%s existing_hit=%s difficulty=%s changed_fields=%s review_status=%s cost_ms=%s",
        q_type,
        question_id,
        len(tag_ids),
        len(tag_names),
        len(resolved_ids),
        created_count,
        existing_hit_count,
        difficulty_action,
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
    scope: CompanyScope = Depends(get_company_scope),
):
    t0 = time.time()
    q_type = _normalize_question_type(question_type)
    obj = get_visible_question(db, scope, q_type, question_id)
    if not obj:
        raise HTTPException(status_code=404, detail="题目不存在")
    logger.info("[ai_tag_suggest:start] q_type=%s q_id=%s", q_type, question_id)

    qa_text = _build_qa_text_for_tag_suggest(q_type, obj)

    # ── 根据 father_tag 查询候选二级标签 ──────────────────
    father_tag_name = (body or {}).get("father_tag") or ""
    candidate_tags = None
    if father_tag_name:
        sub_tags = (
            db.query(Tag)
            .filter(func.find_in_set(father_tag_name, Tag.father_tag) > 0, Tag.is_enabled == 1)
            .all()
        )
        if sub_tags:
            candidate_tags = [t.tag_name for t in sub_tags]

    qa_hash = hashlib.sha256(qa_text.encode("utf-8")).hexdigest()
    ft_hash = hashlib.sha256(father_tag_name.encode("utf-8")).hexdigest() if father_tag_name else "none"
    cache_key = f"{q_type}:{question_id}:{qa_hash}:{ft_hash}"
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
    recommended = extract_tags_from_qa_direct(qa_text, max_tags=5, candidate_tags=candidate_tags)
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
    scope: CompanyScope = Depends(get_company_scope),
):
    q_type = _normalize_question_type(body.get("question_type"))
    limit = max(1, min(int(body.get("limit", 50) or 50), 200))
    only_manual = bool(body.get("only_manual", True))
    auto_apply = bool(body.get("auto_apply", False))
    model = QUESTION_MODEL_MAP[q_type]

    query = db.query(model)
    query = apply_question_scope(query, scope, q_type, model)
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
                scope=scope,
            )
            ok += 1
            details.append({"question_id": int(row.id), "suggested": len(res.get("suggested_tags", []))})
        except Exception:
            failed += 1
    return {"question_type": q_type, "processed": len(rows), "ok": ok, "failed": failed, "details": details}
