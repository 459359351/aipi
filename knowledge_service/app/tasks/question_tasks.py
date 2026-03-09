"""
后台异步任务 —— 基于知识点生成各题型题目，写入 tb_* 表并关联 question_knowledge_rel
"""

import json
import logging
import time
from typing import List, Tuple
from sqlalchemy import text

from ..database import SessionLocal
from ..models.document import Document
from ..models.knowledge_point import KnowledgePoint
from ..models.question import (
    SingleChoice, MultipleChoice, Judge, Essay, QuestionTask,
)
from ..models.question_knowledge_rel import QuestionKnowledgeRel
from ..models.question_tag_rel import question_tag_rel
from ..models.tag import Tag
from ..services.question_generator import (
    generate_single_choices,
    generate_multiple_choices,
    generate_judges,
    generate_essays,
)

logger = logging.getLogger(__name__)


def _build_knowledge_context(kps: list) -> str:
    """将知识点列表拼接为供 LLM 阅读的文本上下文"""
    parts = []
    for i, kp in enumerate(kps, 1):
        tags_str = ""
        if kp.tags:
            tag_names = [t.tag_name for t in kp.tags]
            tags_str = f"  标签: {', '.join(tag_names)}\n"
        parts.append(
            f"【知识点{i}】{kp.title}\n"
            f"{tags_str}"
            f"  {kp.content}\n"
        )
    return "\n".join(parts)


def process_question_task(task_id: int, document_id: int, config: dict) -> None:
    """
    后台出题任务（由 FastAPI BackgroundTasks 调用）

    流程:
    1. 校验文档状态
    2. 查询知识点并拼接上下文
    3. 按配置逐题型调用 LLM 生成
    4. 写入对应 ai_tb_* 表
    5. 更新任务状态和摘要
    """
    db = SessionLocal()
    task_start = time.time()
    result_summary = {}

    try:
        # ── 更新任务状态为 generating ─────────────────────
        task = db.query(QuestionTask).filter(QuestionTask.id == task_id).first()
        if not task:
            logger.error(f"[出题任务] task_id={task_id} 不存在")
            return
        task.status = "generating"
        db.commit()

        logger.info(f"{'='*60}")
        logger.info(f"[出题任务开始] task_id={task_id}, document_id={document_id}")
        logger.info(f"  配置: {json.dumps(config, ensure_ascii=False)}")
        logger.info(f"{'='*60}")

        # ── Step 1: 校验文档 ──────────────────────────────
        doc = db.query(Document).filter(Document.id == document_id).first()
        if not doc:
            raise ValueError(f"文档不存在: document_id={document_id}")
        if doc.status != "completed":
            raise ValueError(f"文档未完成解析: status={doc.status}")

        # ── Step 2: 查询知识点 ────────────────────────────
        kps = (
            db.query(KnowledgePoint)
            .filter(KnowledgePoint.document_id == document_id)
            .all()
        )
        if not kps:
            raise ValueError(f"文档没有知识点: document_id={document_id}")

        knowledge_text = _build_knowledge_context(kps)
        kp_count = len(kps)
        logger.info(f"[Step 2] 加载 {kp_count} 个知识点，上下文 {len(knowledge_text)} 字符")

        qtr_exists = False
        try:
            exists = db.execute(text("SHOW TABLES LIKE 'question_tag_rel'")).fetchone()
            qtr_exists = bool(exists)
        except Exception as e:
            logger.warning("检查 question_tag_rel 是否存在失败: %s", str(e))

        # 1-based 序号 → knowledge_point.id 映射，供写关联关系时使用
        kp_index_map = {i: kp.id for i, kp in enumerate(kps, 1)}
        enabled_tag_ids = {
            int(row[0]) for row in db.query(Tag.id).filter(Tag.is_enabled == 1).all()
        }
        kp_tags_map = {
            kp.id: [
                int(t.id) for t in (kp.tags or [])
                if getattr(t, "id", None) and int(t.id) in enabled_tag_ids
            ]
            for kp in kps
        }

        def _write_knowledge_rels(question_type: str, pairs: List[Tuple]):
            """将 [(orm对象, item)] 的知识点/标签关联关系写入 question_knowledge_rel / question_tag_rel"""
            for q_obj, item in pairs:
                raw_indices = item.get("source_knowledge_indices") or []
                used_kp_ids = set()
                for idx in raw_indices:
                    try:
                        kp_id = kp_index_map.get(int(idx))
                    except (TypeError, ValueError):
                        continue
                    if kp_id is None:
                        continue
                    used_kp_ids.add(kp_id)
                    db.add(QuestionKnowledgeRel(
                        question_type=question_type,
                        question_id=q_obj.id,
                        knowledge_id=kp_id,
                        weight=1,
                    ))

                # 题目标签：从引用的知识点标签汇聚
                tag_ids = set()
                for kp_id in used_kp_ids:
                    for tag_id in kp_tags_map.get(kp_id, []) or []:
                        tag_ids.add(tag_id)
                for tag_id in tag_ids:
                    if not qtr_exists:
                        logger.warning(
                            "跳过 question_tag_rel 写入（表不存在）: question_type=%s, question_id=%s, tag_id=%s",
                            question_type,
                            q_obj.id,
                            tag_id,
                        )
                        continue
                    try:
                        db.execute(
                            question_tag_rel.insert().values(
                                question_type=question_type,
                                question_id=q_obj.id,
                                tag_id=tag_id,
                                is_confirmed=0,
                            )
                        )
                    except Exception as e:
                        raise

        # ── Step 3-A: 单选题 ──────────────────────────────
        sc_count = config.get("single_choice_count", 0)
        sc_effective = kp_count if sc_count <= 0 else sc_count
        if sc_effective > 0:
            logger.info(f"[Step 3-A] 生成 {sc_effective} 道单选题（配置={sc_count}，0=按知识点数）...")
            t0 = time.time()
            sc_items = generate_single_choices(knowledge_text, sc_effective)
            logger.info(f"[Step 3-A] 单选题生成完毕，耗时 {time.time()-t0:.1f}s，得到 {len(sc_items)} 道")
            sc_pairs: List[Tuple] = []
            for item in sc_items:
                q = SingleChoice(
                    document_id=document_id,
                    task_id=task_id,
                    question_text=item["question_text"],
                    option_a=item["option_a"],
                    option_b=item["option_b"],
                    option_c=item["option_c"],
                    option_d=item["option_d"],
                    correct_answer=item["correct_answer"],
                    explanation=item.get("explanation", ""),
                    score=10,
                    review_status=0,
                    is_ai_generated=1,
                )
                db.add(q)
                sc_pairs.append((q, item))
            db.flush()
            _write_knowledge_rels("single", sc_pairs)
            result_summary["single_choice"] = len(sc_items)
        else:
            result_summary["single_choice"] = 0

        # ── Step 3-B: 多选题 ──────────────────────────────
        mc_count = config.get("multiple_choice_count", 0)
        mc_effective = kp_count if mc_count <= 0 else mc_count
        mc_options = config.get("multiple_choice_options", 4)
        if mc_effective > 0:
            logger.info(f"[Step 3-B] 生成 {mc_effective} 道多选题（配置={mc_count}，0=按知识点数，{mc_options} 选项）...")
            t0 = time.time()
            mc_items = generate_multiple_choices(knowledge_text, mc_effective, mc_options)
            logger.info(f"[Step 3-B] 多选题生成完毕，耗时 {time.time()-t0:.1f}s，得到 {len(mc_items)} 道")
            mc_pairs: List[Tuple] = []
            for item in mc_items:
                q = MultipleChoice(
                    document_id=document_id,
                    task_id=task_id,
                    question_text=item["question_text"],
                    option_a=item["option_a"],
                    option_b=item["option_b"],
                    option_c=item["option_c"],
                    option_d=item["option_d"],
                    option_e=item.get("option_e") or "",
                    correct_answer=item["correct_answer"],
                    explanation=item.get("explanation", ""),
                    score=10,
                    review_status=0,
                    is_ai_generated=1,
                )
                db.add(q)
                mc_pairs.append((q, item))
            db.flush()
            _write_knowledge_rels("multiple", mc_pairs)
            result_summary["multiple_choice"] = len(mc_items)
        else:
            result_summary["multiple_choice"] = 0

        # ── Step 3-C: 判断题 ──────────────────────────────
        jg_count = config.get("judge_count", 0)
        jg_effective = kp_count if jg_count <= 0 else jg_count
        if jg_effective > 0:
            logger.info(f"[Step 3-C] 生成 {jg_effective} 道判断题（配置={jg_count}，0=按知识点数）...")
            t0 = time.time()
            jg_items = generate_judges(knowledge_text, jg_effective)
            logger.info(f"[Step 3-C] 判断题生成完毕，耗时 {time.time()-t0:.1f}s，得到 {len(jg_items)} 道")
            jg_pairs: List[Tuple] = []
            for item in jg_items:
                answer_val = item["correct_answer"]
                if isinstance(answer_val, bool):
                    answer_val = 1 if answer_val else 0
                q = Judge(
                    document_id=document_id,
                    task_id=task_id,
                    question_text=item["question_text"],
                    correct_answer=int(answer_val),
                    explanation=item.get("explanation", ""),
                    score=5,
                    review_status=0,
                    is_ai_generated=1,
                )
                db.add(q)
                jg_pairs.append((q, item))
            db.flush()
            _write_knowledge_rels("judge", jg_pairs)
            result_summary["judge"] = len(jg_items)
        else:
            result_summary["judge"] = 0

        # ── Step 3-D: 简答题 ──────────────────────────────
        es_count = config.get("essay_count", 0)
        if es_count > 0:
            logger.info(f"[Step 3-D] 生成 {es_count} 道简答题...")
            t0 = time.time()
            es_items = generate_essays(knowledge_text, es_count)
            logger.info(f"[Step 3-D] 简答题生成完毕，耗时 {time.time()-t0:.1f}s，得到 {len(es_items)} 道")
            es_pairs: List[Tuple] = []
            for item in es_items:
                q = Essay(
                    document_id=document_id,
                    task_id=task_id,
                    question_text=item["question_text"],
                    reference_answer=item["reference_answer"],
                    scoring_rule=item.get("scoring_rule", "[]"),
                    score=20,
                    review_status=0,
                    is_ai_generated=1,
                )
                db.add(q)
                es_pairs.append((q, item))
            db.flush()
            _write_knowledge_rels("essay", es_pairs)
            result_summary["essay"] = len(es_items)
        else:
            result_summary["essay"] = 0

        # ── Step 4: 提交并更新任务 ────────────────────────
        db.commit()

        task.status = "completed"
        task.result_summary = json.dumps(result_summary, ensure_ascii=False)
        task.error_message = None
        db.commit()

        total_elapsed = time.time() - task_start
        logger.info(f"{'='*60}")
        logger.info(f"[出题任务完成] task_id={task_id}, document_id={document_id}")
        logger.info(f"  结果: {json.dumps(result_summary, ensure_ascii=False)}")
        logger.info(f"  总耗时: {total_elapsed:.1f}s")
        logger.info(f"{'='*60}")

    except Exception as e:
        total_elapsed = time.time() - task_start
        logger.error(f"{'='*60}")
        logger.error(f"[出题任务失败] task_id={task_id}, 耗时 {total_elapsed:.1f}s")
        logger.error(f"  错误: {e}", exc_info=True)
        logger.error(f"{'='*60}")
        try:
            db.rollback()
            task = db.query(QuestionTask).filter(QuestionTask.id == task_id).first()
            if task:
                task.status = "failed"
                task.error_message = str(e)
                task.result_summary = json.dumps(result_summary, ensure_ascii=False) if result_summary else None
                db.commit()
        except Exception:
            logger.error("更新任务失败状态时出错", exc_info=True)
    finally:
        db.close()
