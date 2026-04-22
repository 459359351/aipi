-- ============================================
-- 考试平台 AI 知识处理服务 - 建表 SQL
-- 数据库: aipi
-- 执行方式: 使用有 CREATE 权限的账号在 MySQL 中执行
-- ============================================

-- 如需给 aipi_user 授权 CREATE 权限，使用 root 执行以下命令:
-- GRANT CREATE ON aipi.* TO 'aipi_user'@'%';
-- FLUSH PRIVILEGES;

-- ============================================
-- 1. documents 表（文档元数据）
-- ============================================
CREATE TABLE IF NOT EXISTS documents (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    doc_name VARCHAR(255) NOT NULL COMMENT '文档名称',
    doc_type VARCHAR(50) COMMENT '文档类型（教材/大纲/试卷/课件）',
    business_domain VARCHAR(128) COMMENT '业务领域（数学/语文/物理）',
    org_dimension VARCHAR(128) COMMENT '组织维度（学校/年级/班级）',
    version VARCHAR(50) COMMENT '文档版本号',
    effective_date DATE COMMENT '生效日期',
    file_url VARCHAR(512) COMMENT 'MinIO 文件访问 URL',
    file_hash VARCHAR(128) COMMENT '文件 SHA256 哈希',
    file_size BIGINT COMMENT '文件大小（字节）',
    file_format VARCHAR(32) COMMENT '文件格式（pdf/docx/txt）',
    status VARCHAR(32) NOT NULL DEFAULT 'pending' COMMENT '状态: pending/parsing/completed/failed',
    error_message TEXT COMMENT '解析失败时的错误信息',
    security_level VARCHAR(32) DEFAULT 'internal' COMMENT '安全等级（public/internal/confidential）',
    upload_user VARCHAR(128) COMMENT '上传用户标识',
    upload_time DATETIME COMMENT '上传时间',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '记录创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '记录更新时间',
    PRIMARY KEY (id),
    INDEX idx_documents_status (status),
    INDEX idx_documents_file_hash (file_hash)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='文档元数据表';

-- ============================================
-- 1.1 document_company_scope_rel 表（文档-公司作用域）
-- ============================================
CREATE TABLE IF NOT EXISTS document_company_scope_rel (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    document_id BIGINT NOT NULL COMMENT '文档ID',
    company_id VARCHAR(128) NOT NULL COMMENT '公司/分公司作用域ID',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE INDEX uk_document_company_scope_rel (document_id, company_id),
    INDEX idx_dcsr_document_id (document_id),
    INDEX idx_dcsr_company_id (company_id),
    CONSTRAINT fk_dcsr_document FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='文档-公司作用域关联表';

-- ============================================
-- 2. tags 表（标签字典）
-- ============================================
CREATE TABLE IF NOT EXISTS tags (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    tag_name VARCHAR(128) NOT NULL COMMENT '标签名称',
    tag_type VARCHAR(64) COMMENT '标签分类（学科/难度/章节/考点类型）',
    is_enabled TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否可用标签：0 否（候选/待审核），1 是（人工确认）',
    PRIMARY KEY (id),
    UNIQUE INDEX idx_tags_tag_name (tag_name),
    INDEX idx_tags_enabled (is_enabled)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='标签字典表';

-- ============================================
-- 3. knowledge_points 表（知识点）
-- ============================================
CREATE TABLE IF NOT EXISTS knowledge_points (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    document_id BIGINT NOT NULL COMMENT '关联文档 ID',
    title VARCHAR(255) NOT NULL COMMENT '知识点标题',
    content TEXT NOT NULL COMMENT '知识点详细内容',
    summary TEXT COMMENT '知识点摘要',
    importance_score FLOAT DEFAULT 0.0 COMMENT '重要度评分（0.0~1.0，由 LLM 给出）',
    dify_document_id VARCHAR(128) COMMENT 'Dify 知识库中的文档 ID',
    dify_sync_status VARCHAR(32) DEFAULT 'pending' COMMENT 'Dify 同步状态: pending/synced/failed',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (id),
    INDEX idx_kp_document_id (document_id),
    CONSTRAINT fk_kp_document FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='知识点表';

-- ============================================
-- 4. knowledge_tag_rel 表（知识点-标签关联）
-- ============================================
CREATE TABLE IF NOT EXISTS knowledge_tag_rel (
    knowledge_id BIGINT NOT NULL COMMENT '知识点 ID',
    tag_id BIGINT NOT NULL COMMENT '标签 ID',
    PRIMARY KEY (knowledge_id, tag_id),
    CONSTRAINT fk_rel_knowledge FOREIGN KEY (knowledge_id) REFERENCES knowledge_points (id) ON DELETE CASCADE,
    CONSTRAINT fk_rel_tag FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='知识点-标签多对多关联表';

-- ============================================
-- 4.1 question_company_scope_rel 表（无文档题目-公司作用域）
-- ============================================
CREATE TABLE IF NOT EXISTS question_company_scope_rel (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    question_type VARCHAR(16) NOT NULL COMMENT '题型: single/multiple/judge/essay',
    question_id INT NOT NULL COMMENT '题目ID',
    company_id VARCHAR(128) NOT NULL COMMENT '公司/分公司作用域ID',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE INDEX uk_question_company_scope_rel (question_type, question_id, company_id),
    INDEX idx_qcsr_question_type_id (question_type, question_id),
    INDEX idx_qcsr_company_id (company_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='题目-公司作用域关联表（用于无文档题目）';

-- ============================================
-- 完成
-- ============================================
SELECT '建表完成' AS result;
