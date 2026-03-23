"""
标签语义匹配模块 —— 为 position/level 等自由文本匹配标签提供 NLP 增强

三级匹配策略（Level 1 由调用方在 SQL 层完成）：
  Level 1: SQL LIKE '%term%'（调用方执行）
  Level 2: jieba 分词 token 交集匹配
  Level 3: TF-IDF 关键词余弦相似度
"""

import logging
import threading
from typing import Dict, FrozenSet, List, Optional, Set, Tuple

import jieba
import jieba.analyse

logger = logging.getLogger(__name__)

# ── 领域同义词表 ──────────────────────────────────────────
# 用于 Level 2 分词匹配时扩展查询词，提升召回
# key: 原始词  value: 关联词列表（会被加入查询 token 集合）
# ── 停用词表 ──────────────────────────────────────────────
# 在标签域中过于泛化的词，单独出现时匹配无意义，会导致大量误匹配
STOP_WORDS: Set[str] = {
    "工作", "建设", "管理", "制度", "要求", "相关",
    "基本", "理论", "标准", "情形", "事项", "范围",
}

SYNONYM_MAP: Dict[str, List[str]] = {
    "纪检": ["廉政", "纪律检查", "监察", "党风"],
    "组织": ["组织建设", "组织部"],
    "宣传": ["宣传工作", "宣传部"],
    "人事": ["干部", "人才", "干部管理"],
    "培训": ["教育", "党员教育", "培训学习"],
    "考核": ["考试", "测评", "考核标准"],
    "监督": ["党内监督", "监察"],
    "廉政": ["纪检", "党风", "廉政建设"],
    "团委": ["共青团", "团工作"],
    "工会": ["工会工作", "职工"],
}


class TagMatcher:
    """
    标签语义匹配器。

    应用启动时加载所有启用标签的分词结果和 TF-IDF 关键词到内存，
    后续查询直接使用缓存。标签数量 30-50 条，内存占用可忽略。
    """

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._tag_tokens: Dict[int, FrozenSet[str]] = {}
        self._tag_names: Dict[int, str] = {}
        self._tag_tfidf: Dict[int, Dict[str, float]] = {}
        self._initialized = False

    # ── 初始化 ────────────────────────────────────────────

    def load_tags(self, tags: List[Tuple[int, str]]) -> None:
        """
        加载标签列表，预计算分词和 TF-IDF 关键词。

        Args:
            tags: [(tag_id, tag_name), ...] 已启用的标签
        """
        with self._lock:
            self._tag_tokens.clear()
            self._tag_names.clear()
            self._tag_tfidf.clear()

            for tag_id, tag_name in tags:
                name = (tag_name or "").strip()
                if not name:
                    continue

                self._tag_names[tag_id] = name

                # 全模式分词（召回子词，避免自定义高频词被当作整体不可切分）
                tokens = set()
                for word in jieba.cut(name, cut_all=True):
                    w = word.strip()
                    if len(w) >= 2 and w not in STOP_WORDS:
                        tokens.add(w)
                # 确保原名也在 token 集合中
                if len(name) >= 2:
                    tokens.add(name)
                self._tag_tokens[tag_id] = frozenset(tokens)

                # TF-IDF 关键词（利用 jieba.analyse 已配好的 IDF）
                keywords = jieba.analyse.extract_tags(name, topK=10, withWeight=True)
                self._tag_tfidf[tag_id] = {kw: w for kw, w in keywords}

            self._initialized = True
            logger.info("[TagMatcher] 已加载 %d 个标签的分词和 TF-IDF 缓存", len(self._tag_names))

    @property
    def is_initialized(self) -> bool:
        return self._initialized

    # ── 查询匹配 ──────────────────────────────────────────

    def match(
        self,
        query: str,
        exclude_ids: Optional[Set[int]] = None,
        token_threshold: float = 0.30,
        tfidf_threshold: float = 0.20,
        max_results: int = 10,
    ) -> List[Tuple[int, str, float, str]]:
        """
        对 query 文本进行 Level 2 + Level 3 语义匹配。

        Args:
            query:            输入文本（岗位名/级别名等）
            exclude_ids:      需排除的 tag_id（如已被 SQL LIKE 匹配到的）
            token_threshold:  Level 2 词集重叠率阈值
            tfidf_threshold:  Level 3 TF-IDF 余弦相似度阈值
            max_results:      最多返回标签数

        Returns:
            [(tag_id, tag_name, score, match_level), ...] 按 score 降序
            match_level: "token_overlap" | "tfidf_cosine"
        """
        if not self._initialized or not query or not query.strip():
            return []

        query = query.strip()
        exclude = exclude_ids or set()

        query_tokens = self._tokenize_query(query)
        query_tfidf = self._tfidf_for_query(query)

        results: List[Tuple[int, str, float, str]] = []

        for tag_id, tag_name in self._tag_names.items():
            if tag_id in exclude:
                continue

            # ── Level 2: 分词 token 交集 ──
            tag_tokens = self._tag_tokens.get(tag_id, frozenset())
            if query_tokens and tag_tokens:
                overlap = query_tokens & tag_tokens
                if overlap:
                    score = len(overlap) / min(len(query_tokens), len(tag_tokens))
                    if score >= token_threshold:
                        results.append((tag_id, tag_name, round(score, 4), "token_overlap"))
                        continue  # 已命中，跳过 Level 3

            # ── Level 3: TF-IDF 余弦相似度 ──
            tag_tfidf = self._tag_tfidf.get(tag_id, {})
            if query_tfidf and tag_tfidf:
                cosine = self._cosine_similarity(query_tfidf, tag_tfidf)
                if cosine >= tfidf_threshold:
                    results.append((tag_id, tag_name, round(cosine, 4), "tfidf_cosine"))

        results.sort(key=lambda x: -x[2])
        return results[:max_results]

    # ── 内部方法 ──────────────────────────────────────────

    def _tokenize_query(self, text: str) -> FrozenSet[str]:
        """对查询文本分词，含停用词过滤和同义词扩展"""
        tokens: Set[str] = set()
        for word in jieba.cut(text, cut_all=True):  # 全模式，召回更多
            w = word.strip()
            if len(w) >= 2 and w not in STOP_WORDS:
                tokens.add(w)
                # 同义词扩展
                for syn in SYNONYM_MAP.get(w, []):
                    tokens.add(syn)
        if len(text.strip()) >= 2:
            tokens.add(text.strip())
        return frozenset(tokens)

    @staticmethod
    def _tfidf_for_query(text: str) -> Dict[str, float]:
        """对查询文本提取 TF-IDF 关键词"""
        keywords = jieba.analyse.extract_tags(text, topK=10, withWeight=True)
        return {kw: w for kw, w in keywords}

    @staticmethod
    def _cosine_similarity(vec_a: Dict[str, float], vec_b: Dict[str, float]) -> float:
        """
        纯 Python 稀疏向量余弦相似度。
        标签数量少（30-50），关键词少（<=10），性能完全够用。
        """
        common_keys = set(vec_a.keys()) & set(vec_b.keys())
        if not common_keys:
            return 0.0

        dot_product = sum(vec_a[k] * vec_b[k] for k in common_keys)
        norm_a = sum(v * v for v in vec_a.values()) ** 0.5
        norm_b = sum(v * v for v in vec_b.values()) ** 0.5

        if norm_a == 0.0 or norm_b == 0.0:
            return 0.0
        return dot_product / (norm_a * norm_b)


# ── 模块级单例 ────────────────────────────────────────────
_matcher = TagMatcher()


def get_tag_matcher() -> TagMatcher:
    """获取全局 TagMatcher 单例"""
    return _matcher


def refresh_tag_cache(db) -> None:
    """
    从数据库刷新标签缓存。

    调用时机：应用启动（main.py lifespan）、标签 CRUD 后（可选）
    """
    from ..models.tag import Tag

    tags = db.query(Tag.id, Tag.tag_name).filter(Tag.is_enabled == 1).all()
    tag_list = [(int(r[0]), str(r[1])) for r in tags]
    _matcher.load_tags(tag_list)


def match_tags_by_nlp(
    query: str,
    exclude_ids: Optional[Set[int]] = None,
    token_threshold: float = 0.30,
    tfidf_threshold: float = 0.20,
    max_results: int = 10,
) -> List[Tuple[int, str, float, str]]:
    """
    便捷函数：对 query 进行 NLP 语义匹配标签。

    Returns:
        [(tag_id, tag_name, score, match_level), ...]
    """
    return _matcher.match(
        query=query,
        exclude_ids=exclude_ids,
        token_threshold=token_threshold,
        tfidf_threshold=tfidf_threshold,
        max_results=max_results,
    )
