"""
后台异步任务 —— 文档解析 → 知识点抽取 → MySQL 写入 → Dify 同步
"""

import logging
import time

from ..database import SessionLocal
from ..services.minio_service import minio_service
from ..services.parser_service import parse_document
from ..services.knowledge_extractor import extract_knowledge_points
from ..services.dify_service import dify_service
from ..services import document_service
from ..models.tag import Tag

logger = logging.getLogger(__name__)

def process_document_task(document_id: int, object_key: str, file_format: str) -> None:
    """
    后台文档处理任务（由 FastAPI BackgroundTasks 调用）

    完整流程：
    1. 更新状态为 parsing
    2. 从 MinIO 下载文件
    3. 解析文档文本
    4. 调用 LLM 抽取知识点
    5. 写入 MySQL（knowledge_points + tags + 关联表）
    6. 逐条写入 Dify 知识库
    7. 更新状态为 completed

    失败时更新状态为 failed 并记录 error_message
    """
    db = SessionLocal()
    task_start = time.time()
    try:
        # ── Step 1: 标记为解析中 ──────────────────────────
        document_service.update_document_status(db, document_id, "parsing")
        logger.info(f"{'='*60}")
        logger.info(f"[任务开始] document_id={document_id}, 格式={file_format}")
        logger.info(f"{'='*60}")

        # ── Step 2: 从 MinIO 下载文件 ─────────────────────
        t0 = time.time()
        logger.info(f"[Step 2/7] 从 MinIO 下载文件: {object_key}")
        file_data = minio_service.download_file(object_key)
        logger.info(f"[Step 2/7] MinIO 下载完成，文件大小: {len(file_data)} 字节，耗时 {time.time()-t0:.1f}s")

        # ── Step 3: 解析文档文本 ──────────────────────────
        t0 = time.time()
        logger.info(f"[Step 3/7] 开始解析文档内容 (格式: {file_format})")
        text_content = parse_document(file_data, file_format)

        if not text_content or not text_content.strip():
            raise ValueError("文档解析后内容为空")

        logger.info(f"[Step 3/7] 文档解析完成，文本长度: {len(text_content)} 字符，耗时 {time.time()-t0:.1f}s")

        # ── Step 4: LLM 抽取知识点 ────────────────────────
        logger.info(f"[Step 4/7] 调用 LLM 抽取知识点（这一步耗时较长，请耐心等待）...")
        t0 = time.time()
        # 预设标签簇：优先让 LLM 从既有标签里选择；另外产出 new_tags 供人工审核
        tags = db.query(Tag).all()
        preset_tags: dict[str, list[str]] = {}
        for t in tags:
            if int(getattr(t, "is_enabled", 0) or 0) != 1:
                continue
            if not t.tag_type or t.tag_type == "ai":
                continue
            preset_tags.setdefault(t.tag_type, []).append(t.tag_name)

        extracted_points = extract_knowledge_points(text_content, preset_tags=preset_tags)
        logger.info(f"[Step 4/7] LLM 抽取完成，耗时 {time.time()-t0:.1f}s")

        if not extracted_points:
            logger.warning(f"[Step 4/7] document_id={document_id}: LLM 未抽取到知识点")
            document_service.update_document_status(db, document_id, "completed", error_message=None)
            return

        logger.info(f"[Step 4/7] 共抽取到 {len(extracted_points)} 个知识点")

        # ── Step 5: 写入 MySQL ────────────────────────────
        t0 = time.time()
        logger.info(f"[Step 5/7] 开始写入 {len(extracted_points)} 个知识点到 MySQL...")
        saved_kps = document_service.save_knowledge_points(
            db, document_id, extracted_points
        )
        logger.info(f"[Step 5/7] MySQL 写入完成，耗时 {time.time()-t0:.1f}s")

        # ── Step 6: 写入 Dify 知识库 ─────────────────────
        t0 = time.time()
        total_kps = len(saved_kps)
        dify_ok, dify_fail = 0, 0
        logger.info(f"[Step 6/7] 开始同步 {total_kps} 个知识点到 Dify 知识库...")
        for i, (kp, ep) in enumerate(zip(saved_kps, extracted_points)):
            try:
                dify_doc_id = dify_service.write_knowledge_point(
                    title=kp.title,
                    content=kp.content,
                    summary=kp.summary or "",
                    tags=ep.tags,
                )
                if dify_doc_id:
                    kp.dify_document_id = dify_doc_id
                    kp.dify_sync_status = "synced"
                    dify_ok += 1
                else:
                    kp.dify_sync_status = "failed"
                    dify_fail += 1
            except Exception as e:
                logger.warning(f"[Dify] 同步失败 (kp_id={kp.id}): {e}")
                kp.dify_sync_status = "failed"
                dify_fail += 1
            logger.info(f"[Step 6/7] Dify 同步进度: {i+1}/{total_kps} (成功={dify_ok}, 失败={dify_fail})")

        db.commit()
        logger.info(f"[Step 6/7] Dify 同步完成，耗时 {time.time()-t0:.1f}s，成功={dify_ok}, 失败={dify_fail}")

        # ── Step 7: 标记为已完成，同时清空历史错误信息 ─────
        document_service.update_document_status(db, document_id, "completed", error_message=None)
        total_elapsed = time.time() - task_start
        logger.info(f"{'='*60}")
        logger.info(f"[任务完成] document_id={document_id}")
        logger.info(f"  知识点: {len(saved_kps)} 个 | Dify: 成功 {dify_ok} / 失败 {dify_fail}")
        logger.info(f"  总耗时: {total_elapsed:.1f}s")
        logger.info(f"{'='*60}")

    except Exception as e:
        total_elapsed = time.time() - task_start
        logger.error(f"{'='*60}")
        logger.error(f"[任务失败] document_id={document_id}, 耗时 {total_elapsed:.1f}s")
        logger.error(f"  错误: {e}", exc_info=True)
        logger.error(f"{'='*60}")
        try:
            document_service.update_document_status(
                db, document_id, "failed", error_message=str(e)
            )
        except Exception:
            logger.error("更新失败状态时出错", exc_info=True)
    finally:
        db.close()
