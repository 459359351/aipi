-- tb_* 题型表扩展脚本
-- 目的：为正式题库表 tb_single_choices / tb_multiple_choices / tb_judges / tb_essays
--      补充 AI 出题所需的追溯字段和标记字段：
--      - document_id：来源文档 ID（knowledge_service.documents.id）
--      - task_id：出题任务 ID（knowledge_service.question_tasks.id）
--      - review_status：审核状态（0 待审核 / 1 通过 / 2 不通过）
--      - is_ai_generated：是否为 AI 生题（0 非 AI 试题，1 AI 生成试题）
--
-- 注意：
-- 1. 请使用具有 ALTER 权限的 MySQL 账号执行本脚本。
-- 2. 本脚本假定 tb_* 表已按 README 所述创建，且尚未包含以下新增列。
-- 3. 建议在执行前对相关表做备份。

-- 单选题表：tb_single_choices
ALTER TABLE tb_single_choices
    ADD COLUMN document_id BIGINT NULL COMMENT '来源文档 ID' AFTER id,
    ADD COLUMN task_id BIGINT NULL COMMENT '出题任务 ID' AFTER document_id,
    ADD COLUMN review_status SMALLINT NOT NULL DEFAULT 0 COMMENT '审核状态: 0待审核 1通过 2不通过' AFTER score,
    ADD COLUMN is_ai_generated TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否为AI生题: 0非AI 1AI生题' AFTER review_status,
    ADD INDEX idx_tb_sc_document_id (document_id),
    ADD INDEX idx_tb_sc_task_id (task_id);

-- 多选题表：tb_multiple_choices
ALTER TABLE tb_multiple_choices
    ADD COLUMN document_id BIGINT NULL COMMENT '来源文档 ID' AFTER id,
    ADD COLUMN task_id BIGINT NULL COMMENT '出题任务 ID' AFTER document_id,
    ADD COLUMN review_status SMALLINT NOT NULL DEFAULT 0 COMMENT '审核状态: 0待审核 1通过 2不通过' AFTER score,
    ADD COLUMN is_ai_generated TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否为AI生题: 0非AI 1AI生题' AFTER review_status,
    ADD INDEX idx_tb_mc_document_id (document_id),
    ADD INDEX idx_tb_mc_task_id (task_id);

-- 判断题表：tb_judges
ALTER TABLE tb_judges
    ADD COLUMN document_id BIGINT NULL COMMENT '来源文档 ID' AFTER id,
    ADD COLUMN task_id BIGINT NULL COMMENT '出题任务 ID' AFTER document_id,
    ADD COLUMN review_status SMALLINT NOT NULL DEFAULT 0 COMMENT '审核状态: 0待审核 1通过 2不通过' AFTER score,
    ADD COLUMN is_ai_generated TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否为AI生题: 0非AI 1AI生题' AFTER review_status,
    ADD INDEX idx_tb_jg_document_id (document_id),
    ADD INDEX idx_tb_jg_task_id (task_id);

-- 简答题表：tb_essays
ALTER TABLE tb_essays
    ADD COLUMN document_id BIGINT NULL COMMENT '来源文档 ID' AFTER id,
    ADD COLUMN task_id BIGINT NULL COMMENT '出题任务 ID' AFTER document_id,
    ADD COLUMN review_status SMALLINT NOT NULL DEFAULT 0 COMMENT '审核状态: 0待审核 1通过 2不通过' AFTER score,
    ADD COLUMN is_ai_generated TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否为AI生题: 0非AI 1AI生题' AFTER review_status,
    ADD INDEX idx_tb_es_document_id (document_id),
    ADD INDEX idx_tb_es_task_id (task_id);

