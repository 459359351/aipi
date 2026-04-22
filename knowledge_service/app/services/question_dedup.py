"""
知识点去重模块 —— 确保套题中每个知识点只出现在一种题型中

供模拟答题（组卷）和 AI 出题（检测）共用。
"""

import logging
import random
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Set, Tuple

from sqlalchemy import and_, func, select
from sqlalchemy.orm import Session

from ..models.question import SingleChoice, MultipleChoice, Judge, Essay
from ..models.question_knowledge_rel import QuestionKnowledgeRel
from ..models.question_tag_rel import question_tag_rel
from ..models.tag import Tag
from ..security.company_scope import CompanyScope, apply_question_scope

logger = logging.getLogger(__name__)

QUESTION_MODEL_MAP = {
    "single": SingleChoice,
    "multiple": MultipleChoice,
    "judge": Judge,
    "essay": Essay,
}

# 套题默认题目数量范围（旧格式，作为 fallback）
DEFAULT_COUNT_RANGES: Dict[str, Tuple[int, int]] = {
    "single": (3, 8),
    "multiple": (2, 5),
    "judge": (3, 6),
    "essay": (1, 2),
}


def get_configured_counts() -> Dict[str, int]:
    """从 .env 配置读取各题型固定目标数量"""
    from ..config import get_settings
    settings = get_settings()
    return {
        "single": settings.QUESTION_SET_SINGLE,
        "multiple": settings.QUESTION_SET_MULTIPLE,
        "judge": settings.QUESTION_SET_JUDGE,
        "essay": settings.QUESTION_SET_ESSAY,
    }

# 题型处理优先级：单选/判断优先（覆盖知识点少，先分配避免被挤占）
TYPE_PRIORITY = ["single", "judge", "multiple", "essay"]


@dataclass
class QuestionCandidate:
    question_type: str
    question_id: int
    question_obj: object
    fingerprint: frozenset = field(default_factory=frozenset)
    fingerprint_level: int = 0  # 1=knowledge_rel, 2=tags, 3=keywords
    score: float = 0.0


def _extract_fingerprint_from_knowledge_rel(
    db: Session, question_type: str, question_id: int
) -> Set[str]:
    """Tier 1: 从 question_knowledge_rel 提取知识点 ID 指纹"""
    rows = (
        db.query(QuestionKnowledgeRel.knowledge_id)
        .filter(
            QuestionKnowledgeRel.question_type == question_type,
            QuestionKnowledgeRel.question_id == question_id,
        )
        .all()
    )
    return {f"kp:{int(r[0])}" for r in rows}


def _extract_fingerprint_from_tags(
    db: Session, question_type: str, question_id: int
) -> Set[str]:
    """Tier 2: 从 question_tag_rel 提取标签 ID 指纹"""
    rows = db.execute(
        select(question_tag_rel.c.tag_id)
        .select_from(question_tag_rel.join(Tag, Tag.id == question_tag_rel.c.tag_id))
        .where(
            (question_tag_rel.c.question_type == question_type)
            & (question_tag_rel.c.question_id == question_id)
        )
        .where(Tag.is_enabled == 1)
    ).all()
    return {f"tag:{int(r[0])}" for r in rows}


def _extract_fingerprint_from_text(question_text: str) -> Set[str]:
    """Tier 3: 使用 jieba 关键词提取作为兜底指纹"""
    if not question_text or not question_text.strip():
        return set()
    try:
        import jieba.analyse
        keywords = jieba.analyse.extract_tags(question_text, topK=5)
        return {f"kw:{kw}" for kw in keywords}
    except ImportError:
        logger.warning("jieba 未安装，Tier 3 关键词指纹不可用")
        return set()


def extract_fingerprint(
    db: Session,
    question_type: str,
    question_id: int,
    question_text: Optional[str] = None,
) -> Tuple[frozenset, int]:
    """
    提取题目的知识指纹，返回 (fingerprint_set, tier_level)。
    三级降级：knowledge_rel → tags → jieba keywords
    """
    # Tier 1
    fp = _extract_fingerprint_from_knowledge_rel(db, question_type, question_id)
    if fp:
        return frozenset(fp), 1

    # Tier 2
    fp = _extract_fingerprint_from_tags(db, question_type, question_id)
    if fp:
        return frozenset(fp), 2

    # Tier 3
    if question_text:
        fp = _extract_fingerprint_from_text(question_text)
        if fp:
            return frozenset(fp), 3

    return frozenset(), 0


def build_candidate_pool(
    db: Session,
    question_type: str,
    questions: list,
    user_id: Optional[str] = None,
) -> List[QuestionCandidate]:
    """
    为一组题目构建候选池，预加载知识指纹和行为分数。
    questions: ORM 对象列表
    """
    from ..services.recommendation_service import _behavior_penalty

    candidates = []
    for q in questions:
        fp, level = extract_fingerprint(
            db, question_type, q.id,
            question_text=getattr(q, "question_text", None),
        )
        score = _behavior_penalty(db, user_id, question_type, int(q.id))
        candidates.append(QuestionCandidate(
            question_type=question_type,
            question_id=q.id,
            question_obj=q,
            fingerprint=fp,
            fingerprint_level=level,
            score=score,
        ))
    return candidates


@dataclass
class SupplementContext:
    """各 mode 传入的上下文，用于定向补充不足的题型"""
    tag_ids: List[int] = field(default_factory=list)
    knowledge_ids: List[int] = field(default_factory=list)
    document_id: Optional[int] = None
    question_text: Optional[str] = None
    scope: Optional[CompanyScope] = None


def assemble_question_set(
    candidates_by_type: Dict[str, List[QuestionCandidate]],
    count_ranges: Optional[Dict[str, Tuple[int, int]]] = None,
    db: Optional[Session] = None,
    supplement_ctx: Optional[SupplementContext] = None,
) -> Dict[str, List[QuestionCandidate]]:
    """
    贪心去重组卷算法。

    从 .env 读取各题型固定目标数量。
    候选不足时通过 cascade 管道定向补充（标签→知识点→文本→同文档），
    仍不足则从题库随机补满。
    """
    # 使用 .env 配置的固定目标数量
    target_counts = get_configured_counts()

    used_fingerprints: Set[str] = set()
    result: Dict[str, List[QuestionCandidate]] = {}
    # 全局已选集合，跨题型去重
    global_selected: Set[Tuple[str, int]] = set()

    for q_type in TYPE_PRIORITY:
        needed = target_counts.get(q_type, 0)
        if needed <= 0:
            result[q_type] = []
            continue

        cands = candidates_by_type.get(q_type, [])
        # 按行为分数降序排列（高分 = 更需要练习）
        cands_sorted = sorted(cands, key=lambda c: -c.score)

        selected: List[QuestionCandidate] = []
        for c in cands_sorted:
            if len(selected) >= needed:
                break
            if (c.question_type, c.question_id) in global_selected:
                continue

            fp = c.fingerprint
            if not fp:
                selected.append(c)
                global_selected.add((c.question_type, c.question_id))
                continue

            overlap = fp & used_fingerprints
            overlap_ratio = len(overlap) / len(fp)
            if overlap_ratio <= 0.5:
                selected.append(c)
                used_fingerprints |= fp
                global_selected.add((c.question_type, c.question_id))

        # ── 定向补充：通过 cascade 管道 ──
        if len(selected) < needed and db is not None and supplement_ctx is not None:
            from ..services.recommendation_service import _cascade_find_candidates
            cascade_results = _cascade_find_candidates(
                db=db,
                tag_ids=supplement_ctx.tag_ids,
                knowledge_ids=supplement_ctx.knowledge_ids,
                document_id=supplement_ctx.document_id,
                question_text=supplement_ctx.question_text,
                limit=(needed - len(selected)) * 3,
                exclude=global_selected,
                scope=supplement_ctx.scope,
                enable_text_match=True,
            )
            # 只取当前题型的结果
            for c_type, c_id, obj, reason in cascade_results:
                if len(selected) >= needed:
                    break
                if c_type != q_type:
                    continue
                if (c_type, c_id) in global_selected:
                    continue
                fp, level = extract_fingerprint(db, c_type, c_id, getattr(obj, "question_text", None))
                selected.append(QuestionCandidate(
                    question_type=c_type,
                    question_id=c_id,
                    question_obj=obj,
                    fingerprint=fp,
                    fingerprint_level=level,
                    score=0.0,
                ))
                global_selected.add((c_type, c_id))

        # ── 最后兜底：从题库随机补充 ──
        if len(selected) < needed and db is not None:
            model = QUESTION_MODEL_MAP.get(q_type)
            if model:
                exclude_ids = {c.question_id for c in selected}
                supplement_query = db.query(model)
                if supplement_ctx and supplement_ctx.scope:
                    supplement_query = apply_question_scope(
                        supplement_query,
                        supplement_ctx.scope,
                        q_type,
                        model,
                    )
                supplement = (
                    supplement_query
                    .filter(~model.id.in_(exclude_ids) if exclude_ids else True)
                    .order_by(func.rand())
                    .limit(needed - len(selected))
                    .all()
                )
                for q in supplement:
                    if (q_type, q.id) in global_selected:
                        continue
                    fp, level = extract_fingerprint(db, q_type, q.id, getattr(q, "question_text", None))
                    selected.append(QuestionCandidate(
                        question_type=q_type,
                        question_id=q.id,
                        question_obj=q,
                        fingerprint=fp,
                        fingerprint_level=level,
                        score=0.0,
                    ))
                    global_selected.add((q_type, q.id))

        result[q_type] = selected

    return result


def check_task_duplicates(db: Session, task_id: int) -> Dict:
    """
    检测某个出题任务中，不同题型之间是否存在知识点重复。
    返回信息性报告（不修改数据）。供 AI 出题后可选调用。
    """
    from ..models.question import QuestionTask

    task = db.query(QuestionTask).filter(QuestionTask.id == task_id).first()
    if not task:
        return {"error": "任务不存在"}

    # 收集各题型题目的知识指纹
    type_fingerprints: Dict[str, Dict[int, frozenset]] = {}
    for q_type, model in QUESTION_MODEL_MAP.items():
        questions = db.query(model).filter(model.task_id == task_id).all()
        fps: Dict[int, frozenset] = {}
        for q in questions:
            fp, _ = extract_fingerprint(db, q_type, q.id, getattr(q, "question_text", None))
            if fp:
                fps[q.id] = fp
        type_fingerprints[q_type] = fps

    # 检测跨题型重叠
    duplicate_pairs: List[Dict] = []
    types = list(type_fingerprints.keys())
    for i in range(len(types)):
        for j in range(i + 1, len(types)):
            t1, t2 = types[i], types[j]
            for qid1, fp1 in type_fingerprints[t1].items():
                for qid2, fp2 in type_fingerprints[t2].items():
                    overlap = fp1 & fp2
                    if overlap and len(overlap) / min(len(fp1), len(fp2)) > 0.5:
                        duplicate_pairs.append({
                            "type_a": t1, "id_a": qid1,
                            "type_b": t2, "id_b": qid2,
                            "overlap_elements": len(overlap),
                        })

    return {
        "task_id": task_id,
        "duplicate_pairs": duplicate_pairs,
        "total_pairs_checked": sum(
            len(fps) for fps in type_fingerprints.values()
        ),
    }


def get_existing_coverage(db: Session, document_id: int) -> Dict[int, Set[str]]:
    """
    获取某文档下各知识点已被哪些题型覆盖。
    返回 {knowledge_id: {question_type, ...}}
    供 AI 出题时可选使用，避免重复出同知识点同题型。
    """
    from ..models.knowledge_point import KnowledgePoint

    kp_ids = [
        int(r[0])
        for r in db.query(KnowledgePoint.id)
        .filter(KnowledgePoint.document_id == document_id)
        .all()
    ]
    if not kp_ids:
        return {}

    rows = (
        db.query(QuestionKnowledgeRel.knowledge_id, QuestionKnowledgeRel.question_type)
        .filter(QuestionKnowledgeRel.knowledge_id.in_(kp_ids))
        .all()
    )

    coverage: Dict[int, Set[str]] = {}
    for kid, qtype in rows:
        coverage.setdefault(int(kid), set()).add(qtype)
    return coverage
