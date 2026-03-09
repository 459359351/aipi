-- ============================================
-- 一级标签体系迁移脚本
-- ============================================
-- 1) 创建 father_tags 一级标签表
-- 2) tags 表新增 father_tag 列
-- 3) 插入一级标签种子数据
-- 4) 插入/更新二级标签种子数据
-- 5) 禁用不在二级标签列表中的 domain 标签

-- Step 1: 创建 father_tags 表
CREATE TABLE IF NOT EXISTS father_tags (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    tag_name VARCHAR(128) NOT NULL UNIQUE COMMENT '一级标签名称',
    sub_tag_count INT NOT NULL DEFAULT 0 COMMENT '对应的二级标签数量'
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '一级标签表';

-- Step 2: tags 表新增 father_tag 列
ALTER TABLE tags
ADD COLUMN IF NOT EXISTS father_tag VARCHAR(128) NULL COMMENT '对应的一级标签名（多个用逗号分隔）' AFTER tag_type;

-- Step 3: 插入一级标签种子数据
INSERT INTO
    father_tags (tag_name, sub_tag_count)
VALUES ('工会工作', 7),
    ('共青团工作', 4),
    ('CI工作', 2),
    ('舆情工作', 2),
    ('党建工作', 5),
    ('企业文化', 2)
ON DUPLICATE KEY UPDATE
    sub_tag_count = VALUES(sub_tag_count);

-- Step 4: 插入/更新二级标签（tag_type=domain, is_enabled=1, 绑定 father_tag）

-- 工会工作 (7)
INSERT INTO
    tags (
        tag_name,
        tag_type,
        is_enabled,
        father_tag
    )
VALUES (
        '工会组织建设工作',
        'domain',
        1,
        '工会工作'
    ),
    (
        '工会民主管理工作',
        'domain',
        1,
        '工会工作'
    ),
    (
        '工会经济技术工作',
        'domain',
        1,
        '工会工作'
    ),
    (
        '工会财务与经审工作',
        'domain',
        1,
        '工会工作'
    ),
    (
        '工会女职工工作',
        'domain',
        1,
        '工会工作'
    ),
    (
        '职工之家建设工作',
        'domain',
        1,
        '工会工作'
    ),
    ('其他工会工作', 'domain', 1, '工会工作')
ON DUPLICATE KEY UPDATE
    is_enabled = 1,
    father_tag = VALUES(father_tag),
    tag_type = VALUES(tag_type);

-- 共青团工作 (4)
INSERT INTO
    tags (
        tag_name,
        tag_type,
        is_enabled,
        father_tag
    )
VALUES (
        '团的组织建设工作',
        'domain',
        1,
        '共青团工作'
    ),
    (
        '思想政治引领',
        'domain',
        1,
        '共青团工作'
    ),
    (
        '服务青年发展',
        'domain',
        1,
        '共青团工作'
    ),
    (
        '社会实践与志愿服务',
        'domain',
        1,
        '共青团工作'
    )
ON DUPLICATE KEY UPDATE
    is_enabled = 1,
    father_tag = VALUES(father_tag),
    tag_type = VALUES(tag_type);

-- CI工作 (2)
INSERT INTO
    tags (
        tag_name,
        tag_type,
        is_enabled,
        father_tag
    )
VALUES ('标准化文件', 'domain', 1, 'CI工作')
ON DUPLICATE KEY UPDATE
    is_enabled = 1,
    father_tag = VALUES(father_tag),
    tag_type = VALUES(tag_type);

-- 舆情工作 (2) — 注: "制度执行" 同时属于 CI工作 和 舆情工作
INSERT INTO
    tags (
        tag_name,
        tag_type,
        is_enabled,
        father_tag
    )
VALUES ('负面舆情案例', 'domain', 1, '舆情工作')
ON DUPLICATE KEY UPDATE
    is_enabled = 1,
    father_tag = VALUES(father_tag),
    tag_type = VALUES(tag_type);

-- "制度执行" 属于 CI工作 和 舆情工作（逗号分隔）
INSERT INTO
    tags (
        tag_name,
        tag_type,
        is_enabled,
        father_tag
    )
VALUES (
        '制度执行',
        'domain',
        1,
        'CI工作,舆情工作'
    )
ON DUPLICATE KEY UPDATE
    is_enabled = 1,
    father_tag = VALUES(father_tag),
    tag_type = VALUES(tag_type);

-- 党建工作 (5)
INSERT INTO
    tags (
        tag_name,
        tag_type,
        is_enabled,
        father_tag
    )
VALUES ('党员教育发展', 'domain', 1, '党建工作'),
    (
        '党建工作责任制考核',
        'domain',
        1,
        '党建工作'
    )
ON DUPLICATE KEY UPDATE
    is_enabled = 1,
    father_tag = VALUES(father_tag),
    tag_type = VALUES(tag_type);

-- 已有的需要更新 father_tag
UPDATE tags
SET
    father_tag = '党建工作',
    is_enabled = 1
WHERE
    tag_name IN (
        '党的基本制度理论及相关要求',
        '党风廉政建设',
        '组织建设'
    )
    AND tag_type = 'domain';

-- 企业文化 (2) — 已有的需要更新 father_tag
UPDATE tags
SET
    father_tag = '企业文化',
    is_enabled = 1
WHERE
    tag_name IN ('企业文化', '宣传工作')
    AND tag_type = 'domain';

-- Step 5: 禁用不在二级标签列表中的 domain 标签
UPDATE tags
SET
    is_enabled = 0
WHERE
    tag_type = 'domain'
    AND is_enabled = 1
    AND tag_name NOT IN(
        '工会组织建设工作',
        '工会民主管理工作',
        '工会经济技术工作',
        '工会财务与经审工作',
        '工会女职工工作',
        '职工之家建设工作',
        '其他工会工作',
        '团的组织建设工作',
        '思想政治引领',
        '服务青年发展',
        '社会实践与志愿服务',
        '标准化文件',
        '制度执行',
        '负面舆情案例',
        '党的基本制度理论及相关要求',
        '党风廉政建设',
        '党员教育发展',
        '组织建设',
        '党建工作责任制考核',
        '企业文化',
        '宣传工作'
    );

SELECT '迁移完成' AS result;

SELECT CONCAT(
        'father_tags: ', COUNT(*), ' 条'
    ) AS father_tags_count
FROM father_tags;

SELECT CONCAT(
        '二级标签 (domain, is_enabled=1): ', COUNT(*), ' 条'
    ) AS active_domain_tags
FROM tags
WHERE
    tag_type = 'domain'
    AND is_enabled = 1;

SELECT CONCAT(
        '已禁用 domain 标签: ', COUNT(*), ' 条'
    ) AS disabled_domain_tags
FROM tags
WHERE
    tag_type = 'domain'
    AND is_enabled = 0;