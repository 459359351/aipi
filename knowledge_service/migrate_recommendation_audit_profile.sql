-- ============================================
-- 推荐优化：审核日志 + 用户画像 + 行为数据
-- ============================================

CREATE TABLE IF NOT EXISTS question_audit_logs (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    question_type VARCHAR(16) NOT NULL COMMENT '题型: single/multiple/judge/essay',
    question_id INT NOT NULL COMMENT '题目ID',
    operation VARCHAR(32) NOT NULL COMMENT '操作类型: edit/approve/tag_confirm',
    operator VARCHAR(128) NULL COMMENT '操作人',
    before_payload TEXT NULL COMMENT '修改前快照(JSON)',
    after_payload TEXT NULL COMMENT '修改后快照(JSON)',
    remark TEXT NULL COMMENT '备注',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (id),
    KEY idx_qal_q (question_type, question_id),
    KEY idx_qal_op (operation),
    KEY idx_qal_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='题目审核日志';

CREATE TABLE IF NOT EXISTS user_profiles (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    user_id VARCHAR(64) NOT NULL COMMENT '用户ID',
    department VARCHAR(128) NULL COMMENT '部门',
    position VARCHAR(128) NULL COMMENT '岗位',
    interests TEXT NULL COMMENT '兴趣标签(JSON数组)',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_up_user (user_id),
    KEY idx_up_dept (department),
    KEY idx_up_pos (position)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户画像';

CREATE TABLE IF NOT EXISTS user_question_behaviors (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    user_id VARCHAR(64) NOT NULL COMMENT '用户ID',
    question_type VARCHAR(16) NOT NULL COMMENT '题型',
    question_id INT NOT NULL COMMENT '题目ID',
    is_correct TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否答对',
    time_spent_sec INT NOT NULL DEFAULT 0 COMMENT '耗时秒',
    answered_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '作答时间',
    PRIMARY KEY (id),
    KEY idx_uqb_user (user_id),
    KEY idx_uqb_q (question_type, question_id),
    KEY idx_uqb_time (answered_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户做题行为';

SELECT 'recommendation audit/profile migration done' AS result;

