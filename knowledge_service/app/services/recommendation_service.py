"""
题目推荐服务 —— 支持按文档练习、按错题推荐
"""

import json
import logging
import os
from typing import Dict, List, Optional, Set, Tuple


from sqlalchemy import and_, desc, func, select
from sqlalchemy.orm import Session

from ..models.document import Document
from ..models.knowledge_point import KnowledgePoint
from ..models.tag import Tag
from ..models.question import Essay, Judge, MultipleChoice, SingleChoice
from ..models.question_knowledge_rel import QuestionKnowledgeRel
from ..models.question_tag_rel import question_tag_rel
from ..models.knowledge_tag_rel import knowledge_tag_rel
from ..models.user_profile import UserProfile
from ..models.user_question_behavior import UserQuestionBehavior
from ..services import document_service
from ..services.knowledge_extractor import extract_knowledge_points_from_qa
from ..services.tag_matcher import get_tag_matcher, match_tags_by_nlp

logger = logging.getLogger(__name__)

QUESTION_MODEL_MAP = {
    "single": SingleChoice,
    "multiple": MultipleChoice,
    "judge": Judge,
    "essay": Essay,
}


def _resolve_tag_ids_by_terms(db: Session, terms: List[Optional[str]]) -> Set[int]:
    """
    对 terms（如 [position, level]）执行三级标签匹配：
      Level 1: SQL LIKE '%term%'
      Level 2: jieba 分词 token 交集（始终补充，排除 LIKE 已命中的标签）
      Level 3: TF-IDF 余弦相似度（同上）
    """
    matched_ids: Set[int] = set()

    for term in terms:
        if not term or not str(term).strip():
            continue
        term = str(term).strip()

        # ── Level 1: SQL LIKE ──
        rows = db.execute(
            select(Tag.id).where(Tag.is_enabled == 1).where(Tag.tag_name.contains(term))
        ).all()
        like_ids = {int(r[0]) for r in rows}
        matched_ids |= like_ids

        # ── Level 2+3: NLP 始终补充（排除 LIKE 已命中的避免重复） ──
        matcher = get_tag_matcher()
        if not matcher.is_initialized:
            continue

        nlp_results = match_tags_by_nlp(
            query=term,
            exclude_ids=like_ids,
        )
        for tag_id, tag_name, score, match_level in nlp_results:
            matched_ids.add(tag_id)
            logger.debug(
                "[NLP tag match] term='%s' -> tag='%s'(id=%d) score=%.4f level=%s",
                term, tag_name, tag_id, score, match_level,
            )

    return matched_ids


def _behavior_penalty(db: Session, user_id: Optional[str], question_type: str, question_id: int) -> float:
    """
    行为重排分：分值越高表示越应该推荐
    - 历史错误率高：加分
    - 平均耗时长：加分
    - 从未做过：加分
    """
    if not user_id:
        return 0.0
    rows = (
        db.query(UserQuestionBehavior.is_correct, UserQuestionBehavior.time_spent_sec)
        .filter(
            UserQuestionBehavior.user_id == str(user_id),
            UserQuestionBehavior.question_type == question_type,
            UserQuestionBehavior.question_id == question_id,
        )
        .all()
    )
    if not rows:
        return 2.0
    total = len(rows)
    wrong = sum(1 for r in rows if int(r[0] or 0) == 0)
    avg_time = sum(int(r[1] or 0) for r in rows) / total
    wrong_ratio = wrong / total
    return round(wrong_ratio * 2.0 + min(avg_time / 120.0, 1.0), 4)


def _normalize_question_type(question_type: str) -> str:
    normalized = (question_type or "").strip().lower()
    if normalized not in QUESTION_MODEL_MAP:
        raise ValueError("question_type 必须是 single/multiple/judge/essay")
    return normalized


def _serialize_question(
    question_type: str,
    obj,
    related_score: Optional[int] = None,
    recommend_reason: Optional[str] = None,
) -> Dict:
    base = {
        "question_type": question_type,
        "question_id": obj.id,
        "document_id": getattr(obj, "document_id", None),
        "is_ai_generated": int(getattr(obj, "is_ai_generated", 0) or 0),
        "question_text": getattr(obj, "question_text", ""),
        "explanation": getattr(obj, "explanation", None),
        "score": int(getattr(obj, "score", 0) or 0),
        "created_at": getattr(obj, "created_at", None),
        "related_score": related_score,
        "recommend_reason": recommend_reason,
    }
    if question_type == "single":
        base["options"] = {
            "A": obj.option_a,
            "B": obj.option_b,
            "C": obj.option_c,
            "D": obj.option_d,
        }
        base["correct_answer"] = obj.correct_answer
    elif question_type == "multiple":
        options = {
            "A": obj.option_a,
            "B": obj.option_b,
            "C": obj.option_c,
            "D": obj.option_d,
        }
        if getattr(obj, "option_e", None):
            options["E"] = obj.option_e
        base["options"] = options
        base["correct_answer"] = obj.correct_answer
    elif question_type == "judge":
        base["correct_answer"] = obj.correct_answer
    elif question_type == "essay":
        base["reference_answer"] = obj.reference_answer
        base["scoring_rule"] = obj.scoring_rule
    return base


def _load_document_knowledge_ids(db: Session, document_id: int) -> List[int]:
    rows = (
        db.query(KnowledgePoint.id)
        .filter(KnowledgePoint.document_id == document_id)
        .all()
    )
    return [int(r[0]) for r in rows]


def _load_document_tag_ids(db: Session, document_id: int) -> List[int]:
    rows = db.execute(
        select(knowledge_tag_rel.c.tag_id)
        .select_from(knowledge_tag_rel.join(KnowledgePoint, knowledge_tag_rel.c.knowledge_id == KnowledgePoint.id))
        .where(KnowledgePoint.document_id == document_id)
        .join(Tag, Tag.id == knowledge_tag_rel.c.tag_id)
        .where(Tag.is_enabled == 1)
        .distinct()
    ).all()
    return [int(r[0]) for r in rows]


def _load_question_tag_ids(
    db: Session,
    question_type: str,
    question_id: int,
    confirmed_only: bool = False,
) -> List[int]:
    stmt = (
        select(question_tag_rel.c.tag_id)
        .select_from(question_tag_rel.join(Tag, Tag.id == question_tag_rel.c.tag_id))
        .where((question_tag_rel.c.question_type == question_type) & (question_tag_rel.c.question_id == question_id))
        .where(Tag.is_enabled == 1)
    )
    if confirmed_only:
        stmt = stmt.where(question_tag_rel.c.is_confirmed == 1)
    rows = db.execute(stmt).all()
    return [int(r[0]) for r in rows]


def _query_manual_related_questions_by_tags(
    db: Session,
    question_type: str,
    tag_ids: List[int],
    limit: int,
    exclude_ids: Optional[List[int]] = None,
    confirmed_only: bool = True,
):
    """用题目标签做召回：人工题（document_id 为空）且与 tag_ids 有重叠，按重叠数排序。"""
    if not tag_ids:
        return []
    model = QUESTION_MODEL_MAP[question_type]
    query = (
        db.query(model)
        .join(
            question_tag_rel,
            and_(
                question_tag_rel.c.question_type == question_type,
                question_tag_rel.c.question_id == model.id,
            ),
        )
        .filter(model.document_id.is_(None))
        .filter(question_tag_rel.c.tag_id.in_(tag_ids))
        .filter(question_tag_rel.c.is_confirmed == (1 if confirmed_only else 0))
    )
    if exclude_ids:
        query = query.filter(~model.id.in_(exclude_ids))
    return (
        query.group_by(model.id)
        .order_by(desc(func.count(func.distinct(question_tag_rel.c.tag_id))), desc(model.created_at))
        .limit(limit)
        .all()
    )


def _query_document_questions(
    db: Session,
    question_type: str,
    document_id: int,
    limit: int,
) -> List:
    model = QUESTION_MODEL_MAP[question_type]
    return (
        db.query(model)
        .filter(model.document_id == document_id)
        .order_by(func.rand())
        .limit(limit)
        .all()
    )


def _query_manual_related_questions(
    db: Session,
    question_type: str,
    knowledge_ids: List[int],
    limit: int,
    exclude_ids: List[int],
) -> List:
    if not knowledge_ids or limit <= 0:
        return []
    model = QUESTION_MODEL_MAP[question_type]
    query = (
        db.query(model)
        .join(
            QuestionKnowledgeRel,
            and_(
                QuestionKnowledgeRel.question_type == question_type,
                QuestionKnowledgeRel.question_id == model.id,
            ),
        )
        .filter(
            QuestionKnowledgeRel.knowledge_id.in_(knowledge_ids),
            model.document_id.is_(None),
        )
    )
    if exclude_ids:
        query = query.filter(~model.id.in_(exclude_ids))
    return (
        query.group_by(model.id)
        .order_by(
            desc(func.count(func.distinct(QuestionKnowledgeRel.knowledge_id))),
            desc(model.created_at),
        )
        .limit(limit)
        .all()
    )


def recommend_by_document(
    db: Session,
    document_id: int,
    single_count: int = 5,
    multiple_count: int = 5,
    judge_count: int = 5,
    essay_count: int = 2,
    include_manual: bool = True,
    user_id: Optional[str] = None,
) -> Dict:
    doc = db.query(Document).filter(Document.id == document_id).first()
    if not doc:
        raise ValueError("文档不存在")

    requested = {
        "single": max(0, int(single_count)),
        "multiple": max(0, int(multiple_count)),
        "judge": max(0, int(judge_count)),
        "essay": max(0, int(essay_count)),
    }

    knowledge_ids = _load_document_knowledge_ids(db, document_id)
    tag_ids = _load_document_tag_ids(db, document_id)
    result_items: List[Dict] = []
    summary = {
        "single": 0,
        "multiple": 0,
        "judge": 0,
        "essay": 0,
    }

    for q_type, needed in requested.items():
        if needed <= 0:
            continue

        selected = _query_document_questions(
            db=db,
            question_type=q_type,
            document_id=document_id,
            limit=needed,
        )
        selected_ids = [q.id for q in selected]

        if include_manual and len(selected) < needed:
            supplement_confirmed = _query_manual_related_questions_by_tags(
                db=db,
                question_type=q_type,
                tag_ids=tag_ids,
                limit=needed - len(selected),
                exclude_ids=selected_ids,
                confirmed_only=True,
            )
            supplement = list(supplement_confirmed)
            # 已确认标签不足时，放宽到未确认标签
            if len(supplement) < (needed - len(selected)):
                supplement_unconfirmed = _query_manual_related_questions_by_tags(
                    db=db,
                    question_type=q_type,
                    tag_ids=tag_ids,
                    limit=(needed - len(selected)) - len(supplement),
                    exclude_ids=selected_ids + [q.id for q in supplement],
                    confirmed_only=False,
                )
                supplement.extend(supplement_unconfirmed)
            # tags 召回不足时再用知识点兜底
            if len(supplement) < (needed - len(selected)):
                fallback = _query_manual_related_questions(
                    db=db,
                    question_type=q_type,
                    knowledge_ids=knowledge_ids,
                    limit=(needed - len(selected)) - len(supplement),
                    exclude_ids=selected_ids + [q.id for q in supplement],
                )
                supplement.extend(fallback)
            selected.extend(supplement)

        # 混合重排：在规则召回结果上按用户行为难度重排（高分优先）
        if user_id:
            selected.sort(key=lambda x: -_behavior_penalty(db, user_id, q_type, int(x.id)))

        for item in selected:
            reason = "同文档题目" if item.document_id == document_id else "同标签/知识点关联的人工题"
            behavior_score = _behavior_penalty(db, user_id, q_type, int(item.id))
            result_items.append(_serialize_question(q_type, item, related_score=int(behavior_score * 100), recommend_reason=reason))
        summary[q_type] = len(selected)

    return {
        "document_id": document_id,
        "include_manual": include_manual,
        "requested": requested,
        "summary": summary,
        "items": result_items,
    }


def _get_question_obj(db: Session, question_type: str, question_id: int):
    model = QUESTION_MODEL_MAP[question_type]
    return db.query(model).filter(model.id == question_id).first()


def _cascade_find_candidates(
    db: Session,
    tag_ids: List[int],
    knowledge_ids: List[int],
    document_id: Optional[int],
    question_text: Optional[str],
    limit: int,
    exclude: Set[Tuple[str, int]],
    enable_text_match: bool = True,
) -> List[Tuple[str, int, object, str]]:
    """
    共享降级管道：标签 → 知识点 → 题干文本匹配 → 同文档。

    返回 (question_type, question_id, ORM_object, recommend_reason) 元组列表。
    每级之间检查是否已达到 limit，不足才继续下一级。
    exclude 在所有级别共享，避免重复。
    """
    results: List[Tuple[str, int, object, str]] = []
    used = set(exclude)

    # ── 1) 标签优先召回：先 confirmed=1，再 confirmed=0 ──
    if tag_ids:
        for confirmed in (1, 0):
            if len(results) >= limit:
                break
            tag_candidate_rows = db.execute(
                select(
                    question_tag_rel.c.question_type,
                    question_tag_rel.c.question_id,
                    func.count(func.distinct(question_tag_rel.c.tag_id)).label("overlap"),
                )
                .select_from(question_tag_rel.join(Tag, Tag.id == question_tag_rel.c.tag_id))
                .where(question_tag_rel.c.tag_id.in_(tag_ids))
                .where(Tag.is_enabled == 1)
                .where(question_tag_rel.c.is_confirmed == confirmed)
                .group_by(question_tag_rel.c.question_type, question_tag_rel.c.question_id)
                .order_by(desc("overlap"))
            ).all()

            for row in tag_candidate_rows:
                c_type = _normalize_question_type(row[0])
                c_id = int(row[1])
                key = (c_type, c_id)
                if key in used:
                    continue
                obj = _get_question_obj(db, c_type, c_id)
                if not obj:
                    continue
                used.add(key)
                reason = "共享标签(已确认)" if confirmed == 1 else "共享标签(待确认)"
                results.append((c_type, c_id, obj, reason))
                if len(results) >= limit:
                    break

    # ── 2) 知识点兜底召回 ──
    if len(results) < limit and knowledge_ids:
        candidate_rows = (
            db.query(
                QuestionKnowledgeRel.question_type,
                QuestionKnowledgeRel.question_id,
                func.count(func.distinct(QuestionKnowledgeRel.knowledge_id)).label("overlap"),
            )
            .filter(QuestionKnowledgeRel.knowledge_id.in_(knowledge_ids))
            .group_by(QuestionKnowledgeRel.question_type, QuestionKnowledgeRel.question_id)
            .order_by(desc("overlap"), desc(func.max(QuestionKnowledgeRel.created_at)))
            .all()
        )

        for row in candidate_rows:
            c_type = _normalize_question_type(row.question_type)
            c_id = int(row.question_id)
            key = (c_type, c_id)
            if key in used:
                continue
            obj = _get_question_obj(db, c_type, c_id)
            if not obj:
                continue
            used.add(key)
            results.append((c_type, c_id, obj, "共享知识点"))
            if len(results) >= limit:
                break

    # ── 3) 题干文本匹配 ──
    if len(results) < limit and enable_text_match and question_text:
        from .question_text_matcher import find_similar_by_text
        text_matches = find_similar_by_text(
            db=db,
            source_question_text=question_text,
            limit=limit - len(results),
            exclude_ids=used,
        )
        for c_type, c_id, obj in text_matches:
            key = (c_type, c_id)
            if key in used:
                continue
            used.add(key)
            results.append((c_type, c_id, obj, "题干文本相似"))
            if len(results) >= limit:
                break

    # ── 4) 同文档补充 ──
    if len(results) < limit and document_id:
        for c_type, model in QUESTION_MODEL_MAP.items():
            fallback_rows = (
                db.query(model)
                .filter(model.document_id == document_id)
                .order_by(func.rand())
                .limit(limit)
                .all()
            )
            for item in fallback_rows:
                key = (c_type, int(item.id))
                if key in used:
                    continue
                used.add(key)
                results.append((c_type, int(item.id), item, "同文档补充"))
                if len(results) >= limit:
                    break
            if len(results) >= limit:
                break

    return results


def recommend_by_question(
    db: Session,
    question_type: str,
    question_id: int,
    limit: int = 10,
    user_id: Optional[str] = None,
    enable_text_match: bool = True,
) -> Dict:
    normalized_type = _normalize_question_type(question_type)
    limit = max(1, min(int(limit), 50))

    base_obj = _get_question_obj(db, normalized_type, question_id)
    if not base_obj:
        raise ValueError("错题不存在")

    base_question = _serialize_question(
        normalized_type,
        base_obj,
        recommend_reason="基准错题",
    )

    base_tag_ids = _load_question_tag_ids(db, normalized_type, question_id, confirmed_only=True)
    if not base_tag_ids:
        base_tag_ids = _load_question_tag_ids(db, normalized_type, question_id, confirmed_only=False)
    rel_rows = (
        db.query(QuestionKnowledgeRel.knowledge_id)
        .filter(
            QuestionKnowledgeRel.question_type == normalized_type,
            QuestionKnowledgeRel.question_id == question_id,
        )
        .all()
    )
    knowledge_ids = [int(r[0]) for r in rel_rows]

    # 使用共享降级管道
    cascade_results = _cascade_find_candidates(
        db=db,
        tag_ids=base_tag_ids,
        knowledge_ids=knowledge_ids,
        document_id=getattr(base_obj, "document_id", None),
        question_text=getattr(base_obj, "question_text", None),
        limit=limit,
        exclude={(normalized_type, question_id)},
        enable_text_match=enable_text_match,
    )

    # 序列化管道结果
    related_questions: List[Dict] = []
    for c_type, c_id, obj, reason in cascade_results:
        related_questions.append(
            _serialize_question(
                c_type,
                obj,
                related_score=int(_behavior_penalty(db, user_id, c_type, c_id) * 100),
                recommend_reason=reason,
            )
        )

    related_questions.sort(key=lambda x: -(int(x.get("related_score") or 0)))

    return {
        "base_question": base_question,
        "knowledge_ids": knowledge_ids,
        "related_questions": related_questions[:limit],
    }


def recommend_by_profile(
    db: Session,
    user_id: str,
    single_count: int = 5,
    multiple_count: int = 5,
    judge_count: int = 5,
    essay_count: int = 2,
) -> Dict:
    profile = db.query(UserProfile).filter(UserProfile.user_id == str(user_id)).first()
    if not profile:
        raise ValueError("用户画像不存在")

    interests = []
    try:
        interests = json.loads(profile.interests or "[]")
    except Exception:
        interests = []
    interests = [str(x).strip() for x in interests if str(x).strip()]

    tag_ids = set()
    if interests:
        rows = db.execute(
            select(Tag.id).where(Tag.is_enabled == 1).where(Tag.tag_name.in_(interests))
        ).all()
        for r in rows:
            tag_ids.add(int(r[0]))
        # 兴趣词可能是一级标签名，匹配其下所有子标签
        for interest in interests:
            rows = db.execute(
                select(Tag.id).where(Tag.is_enabled == 1).where(Tag.father_tag.contains(interest))
            ).all()
            for r in rows:
                tag_ids.add(int(r[0]))
    # 兜底：按部门/岗位词匹配标签名（三级匹配：LIKE + jieba 分词 + TF-IDF）
    tag_ids |= _resolve_tag_ids_by_terms(db, [profile.department, profile.position])

    requested = {
        "single": max(0, int(single_count)),
        "multiple": max(0, int(multiple_count)),
        "judge": max(0, int(judge_count)),
        "essay": max(0, int(essay_count)),
    }
    summary = {"single": 0, "multiple": 0, "judge": 0, "essay": 0}
    items: List[Dict] = []

    for q_type, need in requested.items():
        if need <= 0:
            continue
        model = QUESTION_MODEL_MAP[q_type]
        query = (
            db.query(model)
            .join(
                question_tag_rel,
                and_(
                    question_tag_rel.c.question_type == q_type,
                    question_tag_rel.c.question_id == model.id,
                ),
            )
            .filter(question_tag_rel.c.tag_id.in_(list(tag_ids)) if tag_ids else True)
            .group_by(model.id)
            .order_by(desc(func.count(func.distinct(question_tag_rel.c.tag_id))), func.rand())
            .limit(need * 3)
        )
        cands = query.all()
        scored = []
        for q in cands:
            score = _behavior_penalty(db, user_id, q_type, int(q.id))
            scored.append((score, q))
        scored.sort(key=lambda x: -x[0])
        selected = [q for _, q in scored[:need]]

        for q in selected:
            items.append(
                _serialize_question(
                    q_type,
                    q,
                    related_score=int(_behavior_penalty(db, user_id, q_type, int(q.id)) * 100),
                    recommend_reason="画像标签匹配+行为重排",
                )
            )
        summary[q_type] = len(selected)

    return {
        "user_id": str(user_id),
        "profile": {
            "department": profile.department,
            "position": profile.position,
            "interests": interests,
        },
        "requested": requested,
        "summary": summary,
        "items": items,
    }


def recommend_by_tags(
    db: Session,
    tag_ids: List[int],
    single_count: int = 5,
    multiple_count: int = 5,
    judge_count: int = 5,
    essay_count: int = 2,
    user_id: Optional[str] = None,
    position: Optional[str] = None,
    level: Optional[str] = None,
) -> Dict:
    """按标签 ID 直接推荐题目（供 Tab C 的获取一道题使用）"""
    if not tag_ids:
        raise ValueError("tag_ids 不能为空")

    # 合并传入的 tag_ids 和 position/level 匹配到的额外标签（三级匹配）
    all_tag_ids = set(tag_ids)
    all_tag_ids |= _resolve_tag_ids_by_terms(db, [position, level])
    all_tag_ids = list(all_tag_ids)

    requested = {
        "single": max(0, int(single_count)),
        "multiple": max(0, int(multiple_count)),
        "judge": max(0, int(judge_count)),
        "essay": max(0, int(essay_count)),
    }
    summary = {"single": 0, "multiple": 0, "judge": 0, "essay": 0}
    items: List[Dict] = []

    for q_type, need in requested.items():
        if need <= 0:
            continue
        model = QUESTION_MODEL_MAP[q_type]
        query = (
            db.query(model)
            .join(
                question_tag_rel,
                and_(
                    question_tag_rel.c.question_type == q_type,
                    question_tag_rel.c.question_id == model.id,
                ),
            )
            .filter(question_tag_rel.c.tag_id.in_(all_tag_ids))
            .group_by(model.id)
            .order_by(
                desc(func.count(func.distinct(question_tag_rel.c.tag_id))),
                func.rand(),
            )
            .limit(need * 3)
        )
        cands = query.all()

        if user_id:
            scored = sorted(cands, key=lambda q: -_behavior_penalty(db, user_id, q_type, int(q.id)))
        else:
            scored = cands
        selected = scored[:need]

        for q in selected:
            score_val = _behavior_penalty(db, user_id, q_type, int(q.id)) if user_id else 0
            items.append(_serialize_question(
                q_type, q,
                related_score=int(score_val * 100),
                recommend_reason="标签匹配",
            ))
        summary[q_type] = len(selected)

    return {
        "tag_ids": all_tag_ids,
        "requested": requested,
        "summary": summary,
        "items": items,
    }


def get_random_wrong_question(
    db: Session,
    user_id: int,
    bank_ids: List[int],
    essay_score_threshold: int = 0,
) -> Optional[Dict]:
    """
    从用户的错题中随机选一道作为种子，通过推荐管道找到相似题，
    返回一道推荐题（非原始错题）。推荐列表为空时降级返回种子题本身。
    返回 {question: 推荐题, seed_question: 种子错题信息} 或 None。
    """
    import random
    from ..models.choice_answer import ChoiceAnswer, CHOICE_TYPE_MAP
    from ..models.answer import Answer

    wrong_questions: List[Tuple[str, int]] = []

    # 选择/判断题错题
    choice_rows = (
        db.query(ChoiceAnswer.question_id, ChoiceAnswer.question_type)
        .filter(
            ChoiceAnswer.user_id == user_id,
            ChoiceAnswer.bank_id.in_(bank_ids),
            ChoiceAnswer.is_correct == 0,
        )
        .all()
    )
    for row in choice_rows:
        q_type_str = CHOICE_TYPE_MAP.get(int(row.question_type))
        if q_type_str:
            wrong_questions.append((q_type_str, int(row.question_id)))

    # 简答题错题
    essay_rows = (
        db.query(Answer.question_id)
        .filter(
            Answer.user_id == user_id,
            Answer.bank_id.in_(bank_ids),
            Answer.score <= essay_score_threshold,
            Answer.ai_final_score.isnot(None),
        )
        .all()
    )
    for row in essay_rows:
        wrong_questions.append(("essay", int(row.question_id)))

    if not wrong_questions:
        return None

    # 去重后随机选一道作为种子
    unique_wrong = list(set(wrong_questions))
    seed_type, seed_id = random.choice(unique_wrong)

    seed_obj = _get_question_obj(db, seed_type, seed_id)
    if not seed_obj:
        return None

    seed_question = _serialize_question(seed_type, seed_obj, recommend_reason="种子错题")

    # 通过推荐管道找相似题
    try:
        rec_result = recommend_by_question(
            db=db,
            question_type=seed_type,
            question_id=seed_id,
            limit=5,
            enable_text_match=True,
        )
        related = rec_result.get("related_questions", [])
        if related:
            recommended = random.choice(related)
            return {"question": recommended, "seed_question": seed_question}
    except Exception as e:
        logger.warning("推荐管道调用失败，降级返回种子题: %s", e)

    # 降级：推荐列表为空或调用失败，返回种子题本身
    return {"question": seed_question, "seed_question": seed_question}


def recommend_question_set(
    db: Session,
    mode: str,
    user_id: Optional[str] = None,
    document_id: Optional[int] = None,
    interests: Optional[List[str]] = None,
    tag_ids: Optional[List[int]] = None,
    position: Optional[str] = None,
    level: Optional[str] = None,
    count_ranges: Optional[Dict] = None,
    wrong_user_id: Optional[int] = None,
    bank_ids: Optional[str] = None,
    essay_score_threshold: int = 0,
) -> Dict:
    """
    组卷：获取一套跨题型知识点不重复的套题。
    mode: "document" | "interest" | "tags" | "wrong_questions"
    """
    from .question_dedup import (
        QUESTION_MODEL_MAP as DEDUP_MODEL_MAP,
        DEFAULT_COUNT_RANGES,
        build_candidate_pool,
        assemble_question_set,
        get_configured_counts,
        SupplementContext,
    )

    # 使用 .env 配置的目标数量来决定候选收集量
    configured_counts = get_configured_counts()

    if count_ranges is None:
        count_ranges = dict(DEFAULT_COUNT_RANGES)

    # ── 第一步：根据 mode 收集各题型候选题 ──
    candidates_by_type: Dict[str, list] = {}
    supplement_ctx = SupplementContext()  # 各 mode 填充自己的上下文

    if mode == "document":
        if not document_id:
            raise ValueError("mode=document 时 document_id 必填")
        doc = db.query(Document).filter(Document.id == document_id).first()
        if not doc:
            raise ValueError("文档不存在")

        knowledge_ids = _load_document_knowledge_ids(db, document_id)
        tag_ids_from_doc = _load_document_tag_ids(db, document_id)
        supplement_ctx = SupplementContext(
            tag_ids=tag_ids_from_doc,
            knowledge_ids=knowledge_ids,
            document_id=document_id,
        )

        for q_type in ("single", "multiple", "judge", "essay"):
            target = configured_counts.get(q_type, 0)
            fetch_limit = max(target * 3, 30)
            model = QUESTION_MODEL_MAP[q_type]
            # 文档内题目
            doc_qs = db.query(model).filter(model.document_id == document_id).order_by(func.rand()).limit(fetch_limit).all()
            # 补充同标签人工题
            doc_ids = [q.id for q in doc_qs]
            supplement = _query_manual_related_questions_by_tags(
                db, q_type, tag_ids_from_doc, limit=fetch_limit, exclude_ids=doc_ids, confirmed_only=False,
            )
            all_qs = doc_qs + list(supplement)
            candidates_by_type[q_type] = build_candidate_pool(db, q_type, all_qs, user_id)

    elif mode == "interest":
        # 与 recommend_by_profile 类似，根据兴趣标签查
        resolved_tag_ids = set()
        if interests:
            # 精确匹配 tag_name
            rows = db.execute(
                select(Tag.id).where(Tag.is_enabled == 1).where(Tag.tag_name.in_(interests))
            ).all()
            for r in rows:
                resolved_tag_ids.add(int(r[0]))
            # 兴趣词可能是一级标签名，匹配其下所有子标签
            for interest in interests:
                rows = db.execute(
                    select(Tag.id).where(Tag.is_enabled == 1).where(Tag.father_tag.contains(interest))
                ).all()
                for r in rows:
                    resolved_tag_ids.add(int(r[0]))

        if not resolved_tag_ids:
            raise ValueError("未匹配到任何标签，请检查兴趣标签输入")

        supplement_ctx = SupplementContext(tag_ids=list(resolved_tag_ids))

        for q_type in ("single", "multiple", "judge", "essay"):
            target = configured_counts.get(q_type, 0)
            fetch_limit = max(target * 3, 30)
            model = QUESTION_MODEL_MAP[q_type]
            qs = (
                db.query(model)
                .join(question_tag_rel, and_(
                    question_tag_rel.c.question_type == q_type,
                    question_tag_rel.c.question_id == model.id,
                ))
                .filter(question_tag_rel.c.tag_id.in_(list(resolved_tag_ids)))
                .group_by(model.id)
                .order_by(desc(func.count(func.distinct(question_tag_rel.c.tag_id))))
                .limit(fetch_limit)
                .all()
            )
            candidates_by_type[q_type] = build_candidate_pool(db, q_type, qs, user_id)

    elif mode == "tags":
        if not tag_ids:
            raise ValueError("mode=tags 时 tag_ids 必填")
        # 如果提供了 position/level，也尝试匹配更多标签（三级匹配）
        extra_tag_ids = set(tag_ids)
        extra_tag_ids |= _resolve_tag_ids_by_terms(db, [position, level])

        all_tag_ids = list(extra_tag_ids)
        supplement_ctx = SupplementContext(tag_ids=all_tag_ids)

        for q_type in ("single", "multiple", "judge", "essay"):
            target = configured_counts.get(q_type, 0)
            fetch_limit = max(target * 3, 30)
            model = QUESTION_MODEL_MAP[q_type]
            qs = (
                db.query(model)
                .join(question_tag_rel, and_(
                    question_tag_rel.c.question_type == q_type,
                    question_tag_rel.c.question_id == model.id,
                ))
                .filter(question_tag_rel.c.tag_id.in_(all_tag_ids))
                .group_by(model.id)
                .order_by(desc(func.count(func.distinct(question_tag_rel.c.tag_id))))
                .limit(fetch_limit)
                .all()
            )
            candidates_by_type[q_type] = build_candidate_pool(db, q_type, qs, user_id)

    elif mode == "wrong_questions":
        if wrong_user_id is None:
            raise ValueError("mode=wrong_questions 时 user_id 必填")
        if not bank_ids:
            raise ValueError("mode=wrong_questions 时 bank_ids 必填")

        from ..services.batch_service import parse_bank_id_range
        from ..models.choice_answer import ChoiceAnswer, CHOICE_TYPE_MAP
        from ..models.answer import Answer

        parsed_bank_ids = parse_bank_id_range(bank_ids)
        if not parsed_bank_ids:
            raise ValueError("bank_ids 解析为空")

        # 1) 查询选择/判断题错题
        wrong_questions: List[Tuple[str, int]] = []  # (question_type_str, question_id)
        choice_rows = (
            db.query(ChoiceAnswer.question_id, ChoiceAnswer.question_type)
            .filter(
                ChoiceAnswer.user_id == wrong_user_id,
                ChoiceAnswer.bank_id.in_(parsed_bank_ids),
                ChoiceAnswer.is_correct == 0,
            )
            .all()
        )
        for row in choice_rows:
            q_type_str = CHOICE_TYPE_MAP.get(int(row.question_type))
            if q_type_str:
                wrong_questions.append((q_type_str, int(row.question_id)))

        # 2) 查询简答题错题
        essay_query = db.query(Answer.question_id).filter(
            Answer.user_id == wrong_user_id,
            Answer.bank_id.in_(parsed_bank_ids),
            Answer.score <= essay_score_threshold,
        )
        # 过滤掉未评分的记录（ai_final_score IS NOT NULL）
        essay_query = essay_query.filter(Answer.ai_final_score.isnot(None))
        essay_rows = essay_query.all()
        for row in essay_rows:
            wrong_questions.append(("essay", int(row.question_id)))

        if not wrong_questions:
            # R12: 无错题返回空结果
            return {
                "mode": mode,
                "total": 0,
                "counts": {},
                "groups": {},
            }

        # 3) 构建排除集合（原始错题不应出现在推荐结果中）
        exclude_set: Set[Tuple[str, int]] = set(wrong_questions)

        # 4) 聚合所有错题的 tag_ids 和 knowledge_ids
        all_tag_ids: Set[int] = set()
        all_knowledge_ids: Set[int] = set()
        all_document_ids: Set[int] = set()

        for q_type, q_id in wrong_questions:
            tag_ids_for_q = _load_question_tag_ids(db, q_type, q_id)
            all_tag_ids.update(tag_ids_for_q)

            kp_rows = (
                db.query(QuestionKnowledgeRel.knowledge_id)
                .filter(
                    QuestionKnowledgeRel.question_type == q_type,
                    QuestionKnowledgeRel.question_id == q_id,
                )
                .all()
            )
            all_knowledge_ids.update(int(r[0]) for r in kp_rows)

            obj = _get_question_obj(db, q_type, q_id)
            if obj and getattr(obj, "document_id", None):
                all_document_ids.add(int(obj.document_id))

        supplement_ctx = SupplementContext(
            tag_ids=list(all_tag_ids),
            knowledge_ids=list(all_knowledge_ids),
            document_id=list(all_document_ids)[0] if all_document_ids else None,
        )

        # 5) 调用共享降级管道（不传 question_text，多道错题题干无法聚合）
        cascade_results = _cascade_find_candidates(
            db=db,
            tag_ids=list(all_tag_ids),
            knowledge_ids=list(all_knowledge_ids),
            document_id=list(all_document_ids)[0] if all_document_ids else None,
            question_text=None,
            limit=100,  # 拿足够多的候选给 assemble 去重
            exclude=exclude_set,
            enable_text_match=False,
        )

        # 6) 按题型分组，构建 QuestionCandidate
        type_grouped: Dict[str, list] = {}
        for c_type, c_id, obj, reason in cascade_results:
            type_grouped.setdefault(c_type, []).append(obj)

        for q_type, qs in type_grouped.items():
            candidates_by_type[q_type] = build_candidate_pool(db, q_type, qs, user_id)

    else:
        raise ValueError(f"不支持的 mode: {mode}")

    # ── 第二步：贪心去重组卷（定向补充 + 兜底随机） ──
    result = assemble_question_set(candidates_by_type, count_ranges, db=db, supplement_ctx=supplement_ctx)

    # ── 第三步：序列化 ──
    groups: Dict[str, list] = {}
    counts: Dict[str, int] = {}
    total = 0
    for q_type in ("single", "multiple", "judge", "essay"):
        selected = result.get(q_type, [])
        serialized = [
            _serialize_question(
                q_type, c.question_obj,
                related_score=int(c.score * 100),
                recommend_reason="套题组卷",
            )
            for c in selected
        ]
        groups[q_type] = serialized
        counts[q_type] = len(serialized)
        total += len(serialized)

    return {
        "mode": mode,
        "total": total,
        "counts": counts,
        "groups": groups,
    }


_match_log_calls = 0

def _any_fragment_in_content(text: str, content: str, min_len: int = 2, max_len: int = 10) -> bool:
    """若题干中任一片段（长度在 [min_len, max_len]）出现在 content 中则返回 True。"""
    if not text or not content or len(text) < min_len:
        return False
    n = len(text)
    for length in range(min_len, min(max_len, n) + 1):
        for i in range(0, n - length + 1):
            frag = text[i : i + length]
            if frag in content:
                return True
    return False


def _match_knowledge_for_question(
    question_text: str,
    kp_list: List[Tuple[int, str, str]],
    max_rels: int = 3,
) -> List[int]:
    """根据题干与知识点标题/内容的简单包含关系，返回匹配的知识点 ID 列表（最多 max_rels 个）。"""
    global _match_log_calls
    if not question_text or not kp_list:
        return []
    text = (question_text or "").strip()
    matched: List[Tuple[int, int]] = []  # (score, kp_id); score 越高越优先
    for kp_id, title, content in kp_list:
        title = (title or "").strip()
        content = (content or "")[:500]
        score = 0
        if len(title) >= 2 and title in text:
            score = 10
        elif len(title) >= 2 and text in content:
            score = 5
        elif len(title) >= 2 and _any_fragment_in_content(text, content, min_len=2, max_len=10):
            # 题干片段出现在知识点内容中（人工题表述常与标题不一致，用内容匹配更易命中）
            score = 5
        elif len(title) >= 2 and title in content and any(c in text for c in title):
            score = 2
        if score > 0:
            matched.append((score, kp_id))
    matched.sort(key=lambda x: -x[0])
    result = [kp_id for _, kp_id in matched[:max_rels]]
    _match_log_calls += 1
    return result


def build_manual_question_knowledge_rel(db: Session) -> Dict:
    """
    为人工作业题目（document_id 为空的题目）提炼知识点并建立关联（标签驱动版本）。

    新逻辑：
    - 对每道人工题（含答案/解析）调用 LLM 提炼 1~3 个知识点
    - 知识点写入 knowledge_points（归入一个「系统文档」：人工题目知识点）
    - 将知识点与题目写入 question_knowledge_rel
    - 知识点 tags 优先匹配预设标签簇；候选新标签写入 tags(tag_type=ai) 供人工审核
    """
    # 预设标签簇：仅启用标签，且排除 ai 类型
    tags = db.query(Tag).all()
    preset_tags: dict[str, list[str]] = {}
    existing_tag_map: dict[str, tuple[str, int]] = {}
    for t in tags:
        existing_tag_map[t.tag_name] = ((t.tag_type or ""), int(t.is_enabled or 0))
        if int(t.is_enabled or 0) != 1:
            continue
        if not t.tag_type or t.tag_type == "ai":
            continue
        preset_tags.setdefault(t.tag_type, []).append(t.tag_name)

    # 系统文档：承载人工题提炼出的知识点
    manual_doc_name = "人工题目知识点（系统）"
    manual_doc = db.query(Document).filter(Document.doc_name == manual_doc_name).first()
    if not manual_doc:
        manual_doc = Document(
            doc_name=manual_doc_name,
            doc_type="system",
            business_domain="党建考试",
            org_dimension="题库",
            status="completed",
            security_level="internal",
        )
        db.add(manual_doc)
        db.commit()
        db.refresh(manual_doc)

    existing = set(
        (row.question_type, row.question_id, row.knowledge_id)
        for row in db.query(
            QuestionKnowledgeRel.question_type,
            QuestionKnowledgeRel.question_id,
            QuestionKnowledgeRel.knowledge_id,
        ).all()
    )


    processed = 0
    created_kps = 0
    created_rels = 0
    skipped = 0
    candidate_tags_seen: set[str] = set()

    for q_type, model in QUESTION_MODEL_MAP.items():
        manual_rows = db.query(model).filter(model.document_id.is_(None)).all()
        for row in manual_rows:
            processed += 1

            # 拼装题目内容（尽量包含答案/解析）
            parts: List[str] = []
            parts.append(f"题型: {q_type}")
            parts.append(f"题干: {getattr(row, 'question_text', '') or ''}")
            if q_type in ("single", "multiple"):
                parts.append("选项:")
                parts.append(f"A. {getattr(row, 'option_a', '') or ''}")
                parts.append(f"B. {getattr(row, 'option_b', '') or ''}")
                parts.append(f"C. {getattr(row, 'option_c', '') or ''}")
                parts.append(f"D. {getattr(row, 'option_d', '') or ''}")
                if getattr(row, "option_e", None):
                    parts.append(f"E. {getattr(row, 'option_e', '') or ''}")
                parts.append(f"答案: {getattr(row, 'correct_answer', '') or ''}")
            elif q_type == "judge":
                parts.append(f"答案: {getattr(row, 'correct_answer', '') or ''}")
            elif q_type == "essay":
                parts.append(f"参考答案: {getattr(row, 'answer', '') or ''}")

            explanation = getattr(row, "explanation", None)
            if explanation:
                parts.append(f"解析: {explanation}")
            qa_text = "\n".join([p for p in parts if p is not None])

            # LLM 提炼知识点
            try:
                extracted = extract_knowledge_points_from_qa(qa_text, preset_tags=preset_tags)
            except Exception as e:
                logger.warning("[build_manual] llm extract failed q_type=%s q_id=%s err=%s", q_type, row.id, e)
                continue

            # 题目标签：从本题新知识点聚合（并去重/避免重复插入）
            per_question_tag_ids: set[int] = set()

            for ep in extracted[:3]:
                kp = KnowledgePoint(
                    document_id=manual_doc.id,
                    title=ep.title,
                    content=ep.content,
                    summary=ep.summary,
                    importance_score=ep.importance_score,
                    dify_sync_status="pending",
                )
                db.add(kp)
                db.flush()
                created_kps += 1

                # 关联预设标签
                for tag_name in ep.tags:
                    tag_type, enabled = existing_tag_map.get(tag_name, ("ai", 0))
                    if enabled != 1:
                        # 非可用标签不自动挂接到知识点
                        document_service.get_or_create_tag(
                            db, tag_name=tag_name, tag_type="ai", is_enabled=0
                        )
                        continue
                    tag = document_service.get_or_create_tag(
                        db, tag_name=tag_name, tag_type=tag_type, is_enabled=1
                    )
                    kp.tags.append(tag)
                    if getattr(tag, "id", None):
                        per_question_tag_ids.add(int(tag.id))

                # 候选新标签：只入 tags 表为 ai（不挂到知识点）
                for cand in ep.new_tags or []:
                    cand_name = str(cand).strip()
                    if not cand_name:
                        continue
                    candidate_tags_seen.add(cand_name)
                    document_service.get_or_create_tag(
                        db, tag_name=cand_name, tag_type="ai", is_enabled=0
                    )

                key = (q_type, row.id, kp.id)
                if key in existing:
                    skipped += 1
                    continue
                db.add(
                    QuestionKnowledgeRel(
                        question_type=q_type,
                        question_id=row.id,
                        knowledge_id=kp.id,
                        weight=1,
                    )
                )
                existing.add(key)
                created_rels += 1

            if per_question_tag_ids:
                existing_q_tags = set(
                    r[0] for r in db.execute(
                        select(question_tag_rel.c.tag_id).where(
                            (question_tag_rel.c.question_type == q_type) &
                            (question_tag_rel.c.question_id == row.id)
                        )
                    ).all()
                )
                for tag_id in (per_question_tag_ids - existing_q_tags):
                    db.execute(
                        question_tag_rel.insert().values(
                            question_type=q_type,
                            question_id=row.id,
                            tag_id=tag_id,
                            is_confirmed=0,
                        )
                    )

    db.commit()
    return {
        "processed_questions": processed,
        "created_knowledge_points": created_kps,
        "created_rels": created_rels,
        "skipped_already": skipped,
        "manual_kp_document_id": manual_doc.id,
        "candidate_tags_count": len(candidate_tags_seen),
    }

