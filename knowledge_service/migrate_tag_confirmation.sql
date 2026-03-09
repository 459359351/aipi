-- ============================================
-- 标签可用性 + 题目标签人工确认：增量迁移
-- 说明：用于已上线库的二次升级，请执行一次。
-- ============================================

-- 1) tags: 新增 is_enabled（标签是否可用）
ALTER TABLE tags
    ADD COLUMN is_enabled TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否可用标签：0 否（候选/待审核），1 是（人工确认）';

ALTER TABLE tags
    ADD INDEX idx_tags_enabled (is_enabled);

-- 2) question_tag_rel: 新增 is_confirmed（题目标签关联是否已确认）
ALTER TABLE question_tag_rel
    ADD COLUMN is_confirmed TINYINT(1) NOT NULL DEFAULT 0 COMMENT '关联是否已人工确认：0 否，1 是';

ALTER TABLE question_tag_rel
    ADD INDEX idx_qtr_confirmed (is_confirmed);

-- 3) 存量标签回填：非 candidate 默认视为可用
UPDATE tags
SET is_enabled = 1
WHERE COALESCE(tag_type, '') <> 'candidate';

SELECT 'tag confirmation migration done' AS result;

