-- 题目推荐能力扩展脚本
-- 目的：新增 question_knowledge_rel，用于“题目-知识点”关联，支撑按错题推荐与跨文档补题。

CREATE TABLE IF NOT EXISTS question_knowledge_rel (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    question_type VARCHAR(16) NOT NULL COMMENT '题型: single/multiple/judge/essay',
    question_id INT NOT NULL COMMENT '题目ID（对应 tb_* 主键）',
    knowledge_id BIGINT NOT NULL COMMENT '知识点ID（knowledge_points.id）',
    weight TINYINT NOT NULL DEFAULT 1 COMMENT '关联权重（1~3，可选）',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (id),
    KEY idx_qkr_question_type_id (question_type, question_id),
    KEY idx_qkr_knowledge_id (knowledge_id),
    UNIQUE KEY uk_qkr_question_knowledge (question_type, question_id, knowledge_id),
    CONSTRAINT fk_qkr_knowledge_id
        FOREIGN KEY (knowledge_id) REFERENCES knowledge_points(id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='题目与知识点关联表';

