"""
题干文本相似度匹配模块 —— 基于 jieba TF-IDF 关键词的稀疏向量余弦相似度

供降级管道在标签/知识点匹配不足时，按题干语义查找相似题目。
"""

import logging
from typing import Dict, List, Set, Tuple

import jieba.analyse
from sqlalchemy.orm import Session

from ..models.question import SingleChoice, MultipleChoice, Judge, Essay
from ..security.company_scope import CompanyScope, apply_question_scope

logger = logging.getLogger(__name__)

QUESTION_MODEL_MAP = {
    "single": SingleChoice,
    "multiple": MultipleChoice,
    "judge": Judge,
    "essay": Essay,
}

# 每张题型表最多加载的候选数量
_PER_TABLE_CAP = 50


def _extract_tfidf_vector(text: str, topK: int = 10) -> Dict[str, float]:
    """用 jieba TF-IDF 提取关键词及权重，返回稀疏向量 {keyword: weight}"""
    if not text or not text.strip():
        return {}
    keywords = jieba.analyse.extract_tags(text, topK=topK, withWeight=True)
    return {kw: w for kw, w in keywords}


def _cosine_similarity(vec_a: Dict[str, float], vec_b: Dict[str, float]) -> float:
    """稀疏向量余弦相似度（与 TagMatcher._cosine_similarity 相同算法）"""
    common_keys = set(vec_a.keys()) & set(vec_b.keys())
    if not common_keys:
        return 0.0
    dot_product = sum(vec_a[k] * vec_b[k] for k in common_keys)
    norm_a = sum(v * v for v in vec_a.values()) ** 0.5
    norm_b = sum(v * v for v in vec_b.values()) ** 0.5
    if norm_a == 0.0 or norm_b == 0.0:
        return 0.0
    return dot_product / (norm_a * norm_b)


def find_similar_by_text(
    db: Session,
    source_question_text: str,
    limit: int = 10,
    exclude_ids: Set[Tuple[str, int]] | None = None,
    scope: CompanyScope | None = None,
    similarity_threshold: float = 0.20,
) -> List[Tuple[str, int, object]]:
    """
    按题干文本相似度查找相似题目。

    Args:
        db: 数据库 session
        source_question_text: 源题干文本
        limit: 返回数量上限
        exclude_ids: 需要排除的 (question_type, question_id) 集合
        similarity_threshold: 最低相似度阈值

    Returns:
        List of (question_type, question_id, ORM_object)，按相似度降序
    """
    if not source_question_text or not source_question_text.strip():
        return []

    exclude_ids = exclude_ids or set()
    source_vec = _extract_tfidf_vector(source_question_text)
    if not source_vec:
        return []

    scored: List[Tuple[float, str, int, object]] = []

    for q_type, model in QUESTION_MODEL_MAP.items():
        query = db.query(model)
        if scope is not None:
            query = apply_question_scope(query, scope, q_type, model)
        candidates = query.order_by(model.id.desc()).limit(_PER_TABLE_CAP).all()
        for q in candidates:
            if (q_type, q.id) in exclude_ids:
                continue
            q_text = getattr(q, "question_text", None)
            if not q_text:
                continue
            candidate_vec = _extract_tfidf_vector(q_text)
            if not candidate_vec:
                continue
            sim = _cosine_similarity(source_vec, candidate_vec)
            if sim >= similarity_threshold:
                scored.append((sim, q_type, q.id, q))

    scored.sort(key=lambda x: -x[0])
    return [(q_type, q_id, obj) for _, q_type, q_id, obj in scored[:limit]]
