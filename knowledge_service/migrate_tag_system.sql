-- ============================================
-- 标签驱动推荐：补充 question_tag_rel 表
-- ============================================

CREATE TABLE IF NOT EXISTS question_tag_rel (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    question_type VARCHAR(16) NOT NULL COMMENT '题型: single/multiple/judge/essay',
    question_id INT NOT NULL COMMENT '题目ID（对应 tb_* 主键）',
    tag_id BIGINT NOT NULL COMMENT '标签ID',
    is_confirmed TINYINT(1) NOT NULL DEFAULT 0 COMMENT '关联是否已人工确认：0 否，1 是',
    PRIMARY KEY (id),
    KEY idx_qtr_question (question_type, question_id),
    KEY idx_qtr_tag (tag_id),
    KEY idx_qtr_confirmed (is_confirmed),
    UNIQUE KEY uk_question_tag_rel (question_type, question_id, tag_id),
    CONSTRAINT fk_qtr_tag_id
        FOREIGN KEY (tag_id) REFERENCES tags(id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='题目与标签多对多关联表';

-- tags 补充可用标识（兼容旧库）
ALTER TABLE tags
    ADD COLUMN is_enabled TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否可用标签：0 否（候选/待审核），1 是（人工确认）';

ALTER TABLE tags
    ADD INDEX idx_tags_enabled (is_enabled);

ALTER TABLE question_tag_rel
    ADD COLUMN is_confirmed TINYINT(1) NOT NULL DEFAULT 0 COMMENT '关联是否已人工确认：0 否，1 是';

ALTER TABLE question_tag_rel
    ADD INDEX idx_qtr_confirmed (is_confirmed);

-- ============================================
-- 预设标签数据（党建领域常用标签）
-- ============================================

-- domain: 业务/主题
INSERT IGNORE INTO tags (tag_name, tag_type, is_enabled) VALUES
('企业战略与经营管理', 'domain', 1),
('党的基本制度理论及相关要求', 'domain', 1),
('企业文化', 'domain', 1),
('组织建设', 'domain', 1),
('党员发展教育', 'domain', 1),
('党风廉政建设', 'domain', 1),
('宣传工作', 'domain', 1),
('CI工作', 'domain', 1),
('舆情工作', 'domain', 1),
('工会工作', 'domain', 1),
('共青团工作', 'domain', 1);

-- knowledge_type: 知识类型
INSERT IGNORE INTO tags (tag_name, tag_type, is_enabled) VALUES
('定义', 'knowledge_type', 1),
('流程', 'knowledge_type', 1),
('数字', 'knowledge_type', 1),
('时间节点', 'knowledge_type', 1),
('职责权限', 'knowledge_type', 1),
('禁止事项', 'knowledge_type', 1),
('原则', 'knowledge_type', 1),
('制度要求', 'knowledge_type', 1);

-- difficulty: 难度（可选）
INSERT IGNORE INTO tags (tag_name, tag_type, is_enabled) VALUES
('基础', 'difficulty', 1),
('进阶', 'difficulty', 1);

UPDATE tags
SET is_enabled = 1
WHERE tag_type IN ('domain', 'chapter', 'knowledge_type', 'difficulty')
  AND tag_type <> 'candidate';

SELECT '标签系统迁移完成' AS result;
