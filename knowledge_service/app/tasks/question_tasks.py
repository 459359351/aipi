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
from ..services.difficulty_allocator import allocate, resolve_strategy

logger = logging.getLogger(__name__)


def _build_knowledge_context(kps: list, existing_coverage: dict = None) -> str:
    """
    将知识点列表拼接为供 LLM 阅读的文本上下文。

    existing_coverage: 可选，{kp_id: set_of_question_types}。
    当提供时，会在知识点后附加已有题型标注，提示 LLM 避免重复出同题型。
    """
    type_label = {"single": "单选", "multiple": "多选", "judge": "判断", "essay": "简答"}
    parts = []
    for i, kp in enumerate(kps, 1):
        tags_str = ""
        if kp.tags:
            tag_names = [t.tag_name for t in kp.tags]
            tags_str = f"  标签: {', '.join(tag_names)}\n"
        coverage_str = ""
        if existing_coverage and kp.id in existing_coverage:
            types = existing_coverage[kp.id]
            labels = [type_label.get(t, t) for t in types]
            coverage_str = f"  [已有题型: {', '.join(labels)}]\n"
        parts.append(
            f"【知识点{i}】{kp.title}\n"
            f"{tags_str}"
            f"{coverage_str}"
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

        # 难度标签 name → id 映射（用于写 question_tag_rel difficulty 行）
        difficulty_tag_id_map: dict[str, int] = {
            str(row.tag_name): int(row.id)
            for row in db.query(Tag).filter(Tag.tag_type == "difficulty").all()
        }

        def _run_with_difficulty(gen_fn, knowledge_text, count, strategy, **gen_kwargs):
            """按策略分档调生成器；返回 [(item, difficulty_or_None), ...]"""
            allocation = resolve_strategy(strategy)
            if allocation is None:
                items = gen_fn(knowledge_text, count, **gen_kwargs)
                return [(it, None) for it in items]
            buckets = allocate(count, allocation)
            out: list[tuple[dict, str | None]] = []
            for level, n in buckets.items():
                if n <= 0:
                    continue
                try:
                    part = gen_fn(knowledge_text, n, difficulty=level, **gen_kwargs)
                    logger.info(
                        "[难度分档] level=%s 期望=%d 实得=%d", level, n, len(part)
                    )
                    out.extend((it, level) for it in part)
                except Exception as exc:  # pragma: no cover - defensive
                    logger.warning(
                        "[难度分档] level=%s 生成失败，skip: %s", level, exc
                    )
            return out

        def _write_knowledge_rels(question_type: str, pairs: List[Tuple]):
            """将 [(orm对象, item[, difficulty])] 的知识点/标签关联关系写入 question_knowledge_rel / question_tag_rel

            pairs 元素为 2 元或 3 元组：
              - (q_obj, item)          — 无难度档
              - (q_obj, item, level)   — 附加难度档（level ∈ 简单/一般/困难）
            """
            for entry in pairs:
                if len(entry) == 3:
                    q_obj, item, difficulty_level = entry
                else:
                    q_obj, item = entry
                    difficulty_level = None
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
                    db.execute(
                        question_tag_rel.insert().values(
                            question_type=question_type,
                            question_id=q_obj.id,
                            tag_id=tag_id,
                            is_confirmed=0,
                        )
                    )

                # 写难度 rel（is_confirmed=0，AI 建议值）
                if difficulty_level and qtr_exists:
                    diff_tag_id = difficulty_tag_id_map.get(difficulty_level)
                    if diff_tag_id is None:
                        logger.warning(
                            "难度标签 '%s' 未在 tags 表中找到，跳过 question_tag_rel 写入",
                            difficulty_level,
                        )
                    else:
                        db.execute(
                            question_tag_rel.insert().prefix_with("IGNORE").values(
                                question_type=question_type,
                                question_id=q_obj.id,
                                tag_id=diff_tag_id,
                                is_confirmed=0,
                            )
                        )

        # ── Step 3-A: 单选题 ──────────────────────────────
        # count 语义: None(键不存在)=跳过, 0=按知识点数, >0=指定数量
        sc_count = config.get("single_choice_count")
        if sc_count is None:
            result_summary["single_choice"] = 0
        else:
            sc_effective = kp_count if sc_count <= 0 else sc_count
            if sc_effective > 0:
                sc_strategy = config.get("single_choice_difficulty_strategy")
                logger.info(
                    f"[Step 3-A] 生成 {sc_effective} 道单选题（配置={sc_count}，0=按知识点数，strategy={sc_strategy}）..."
                )
                t0 = time.time()
                sc_results = _run_with_difficulty(
                    generate_single_choices, knowledge_text, sc_effective, sc_strategy
                )
                logger.info(
                    f"[Step 3-A] 单选题生成完毕，耗时 {time.time()-t0:.1f}s，得到 {len(sc_results)} 道"
                )
                sc_pairs: List[Tuple] = []
                for item, diff in sc_results:
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
                    sc_pairs.append((q, item, diff))
                db.flush()
                _write_knowledge_rels("single", sc_pairs)
                result_summary["single_choice"] = len(sc_results)
            else:
                result_summary["single_choice"] = 0

        # ── Step 3-B: 多选题 ──────────────────────────────
        mc_count = config.get("multiple_choice_count")
        if mc_count is None:
            result_summary["multiple_choice"] = 0
        else:
            mc_effective = kp_count if mc_count <= 0 else mc_count
            mc_options = config.get("multiple_choice_options", 4)
            if mc_effective > 0:
                mc_strategy = config.get("multiple_choice_difficulty_strategy")
                logger.info(
                    f"[Step 3-B] 生成 {mc_effective} 道多选题（配置={mc_count}，0=按知识点数，{mc_options} 选项，strategy={mc_strategy}）..."
                )
                t0 = time.time()
                mc_results = _run_with_difficulty(
                    generate_multiple_choices,
                    knowledge_text,
                    mc_effective,
                    mc_strategy,
                    option_count=mc_options,
                )
                logger.info(
                    f"[Step 3-B] 多选题生成完毕，耗时 {time.time()-t0:.1f}s，得到 {len(mc_results)} 道"
                )
                mc_pairs: List[Tuple] = []
                for item, diff in mc_results:
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
                    mc_pairs.append((q, item, diff))
                db.flush()
                _write_knowledge_rels("multiple", mc_pairs)
                result_summary["multiple_choice"] = len(mc_results)
            else:
                result_summary["multiple_choice"] = 0

        # ── Step 3-C: 判断题 ──────────────────────────────
        jg_count = config.get("judge_count")
        if jg_count is None:
            result_summary["judge"] = 0
        else:
            jg_effective = kp_count if jg_count <= 0 else jg_count
            if jg_effective > 0:
                jg_strategy = config.get("judge_difficulty_strategy")
                logger.info(
                    f"[Step 3-C] 生成 {jg_effective} 道判断题（配置={jg_count}，0=按知识点数，strategy={jg_strategy}）..."
                )
                t0 = time.time()
                jg_results = _run_with_difficulty(
                    generate_judges, knowledge_text, jg_effective, jg_strategy
                )
                logger.info(
                    f"[Step 3-C] 判断题生成完毕，耗时 {time.time()-t0:.1f}s，得到 {len(jg_results)} 道"
                )
                jg_pairs: List[Tuple] = []
                for item, diff in jg_results:
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
                    jg_pairs.append((q, item, diff))
                db.flush()
                _write_knowledge_rels("judge", jg_pairs)
                result_summary["judge"] = len(jg_results)
            else:
                result_summary["judge"] = 0

        # ── Step 3-D: 简答题 ──────────────────────────────
        es_count = config.get("essay_count")
        if es_count is None or es_count <= 0:
            result_summary["essay"] = 0
        else:
            es_strategy = config.get("essay_difficulty_strategy")
            logger.info(f"[Step 3-D] 生成 {es_count} 道简答题（strategy={es_strategy}）...")
            t0 = time.time()
            es_results = _run_with_difficulty(
                generate_essays, knowledge_text, es_count, es_strategy
            )
            logger.info(
                f"[Step 3-D] 简答题生成完毕，耗时 {time.time()-t0:.1f}s，得到 {len(es_results)} 道"
            )
            es_pairs: List[Tuple] = []
            for item, diff in es_results:
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
                es_pairs.append((q, item, diff))
            db.flush()
            _write_knowledge_rels("essay", es_pairs)
            result_summary["essay"] = len(es_results)

        # ── Step 4: 提交并更新任务 ────────────────────────
        db.commit()

        # 可选：跨题型知识点重复检测（信息性，不修改数据）
        try:
            from ..services.question_dedup import check_task_duplicates
            dedup_info = check_task_duplicates(db, task_id)
            if dedup_info.get("duplicate_pairs"):
                logger.warning(
                    "[出题] task_id=%s 检测到 %d 对跨题型知识点重复",
                    task_id, len(dedup_info["duplicate_pairs"]),
                )
                result_summary["dedup_warning"] = dedup_info
        except Exception as e:
            logger.debug("[出题] 去重检测跳过: %s", e)

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
