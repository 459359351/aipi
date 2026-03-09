-- AI 出题功能 —— 数据库迁移脚本
-- 为已有的 4 张题型表添加 document_id 和 task_id 列，
-- 并创建 question_tasks 任务跟踪表。
-- 请使用具有 ALTER/CREATE 权限的账号执行。

-- 1. 单选题表：添加追溯列和索引
ALTER TABLE ai_tb_single_choices
    ADD COLUMN document_id BIGINT NULL COMMENT '来源文档 ID' AFTER id,
    ADD COLUMN task_id BIGINT NULL COMMENT '出题任务 ID' AFTER document_id,
    ADD INDEX idx_sc_document_id (document_id),
    ADD INDEX idx_sc_task_id (task_id);

-- 2. 多选题表：添加追溯列和索引
ALTER TABLE ai_tb_multiple_choices
    ADD COLUMN document_id BIGINT NULL COMMENT '来源文档 ID' AFTER id,
    ADD COLUMN task_id BIGINT NULL COMMENT '出题任务 ID' AFTER document_id,
    ADD INDEX idx_mc_document_id (document_id),
    ADD INDEX idx_mc_task_id (task_id);

-- 3. 判断题表：添加追溯列和索引
ALTER TABLE ai_tb_judges
    ADD COLUMN document_id BIGINT NULL COMMENT '来源文档 ID' AFTER id,
    ADD COLUMN task_id BIGINT NULL COMMENT '出题任务 ID' AFTER document_id,
    ADD INDEX idx_jg_document_id (document_id),
    ADD INDEX idx_jg_task_id (task_id);

-- 4. 简答题表：添加追溯列和索引
ALTER TABLE ai_tb_essays
    ADD COLUMN document_id BIGINT NULL COMMENT '来源文档 ID' AFTER id,
    ADD COLUMN task_id BIGINT NULL COMMENT '出题任务 ID' AFTER document_id,
    ADD INDEX idx_es_document_id (document_id),
    ADD INDEX idx_es_task_id (task_id);

-- 5. 创建出题任务跟踪表
CREATE TABLE IF NOT EXISTS question_tasks (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    document_id BIGINT NOT NULL COMMENT '关联文档 ID',
    status VARCHAR(32) NOT NULL DEFAULT 'pending' COMMENT 'pending/generating/completed/failed',
    config TEXT NULL COMMENT '题型数量配置 JSON',
    error_message TEXT NULL COMMENT '失败错误信息',
    result_summary TEXT NULL COMMENT '生成结果摘要 JSON',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_qt_document_id (document_id),
    INDEX idx_qt_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='AI 出题任务跟踪表';
