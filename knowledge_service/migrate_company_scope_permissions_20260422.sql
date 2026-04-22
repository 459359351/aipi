-- 公司作用域权限：文档归属与无文档题目归属桥接表

CREATE TABLE IF NOT EXISTS document_company_scope_rel (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    document_id BIGINT NOT NULL COMMENT '文档ID',
    company_id VARCHAR(128) NOT NULL COMMENT '公司/分公司作用域ID',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_document_company_scope_rel (document_id, company_id),
    KEY idx_dcsr_document_id (document_id),
    KEY idx_dcsr_company_id (company_id),
    CONSTRAINT fk_dcsr_document FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='文档-公司作用域关联表';

CREATE TABLE IF NOT EXISTS question_company_scope_rel (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    question_type VARCHAR(16) NOT NULL COMMENT '题型: single/multiple/judge/essay',
    question_id INT NOT NULL COMMENT '题目ID',
    company_id VARCHAR(128) NOT NULL COMMENT '公司/分公司作用域ID',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_question_company_scope_rel (question_type, question_id, company_id),
    KEY idx_qcsr_question_type_id (question_type, question_id),
    KEY idx_qcsr_company_id (company_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='题目-公司作用域关联表（用于无文档题目）';
