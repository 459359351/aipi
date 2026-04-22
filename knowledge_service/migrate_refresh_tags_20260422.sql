-- ============================================
-- 一级/二级标签体系全量刷新脚本 (2026-04-22)
-- 来源：副本标签信息.xlsx（Sheet1，共 67 个二级标签，9 个一级标签）
-- ============================================
-- 执行策略：
--   1) 先禁用现有全部 domain/human 标签（tag_type='ai', is_enabled=0）
--      — 保留行与主键以维持 documents_tags_rel / question_tag_rel / knowledge_tag_rel 的外键引用
--   2) 删除不在新列表中的 father_tags（外键 ON DELETE CASCADE，会级联清理 documents_tags_rel 中对应绑定）
--   3) UPSERT 9 个新一级标签，刷新 sub_tag_count
--   4) UPSERT 67 个新二级标签（tag_type='human', is_enabled=1，绑定 father_tag）
--   5) 输出校验结果
--
-- 注意：此脚本使用事务包裹，失败会整体回滚。执行前请务必备份。

START TRANSACTION;

-- ============================================================
-- Step 1: 禁用现有全部 domain/human 二级标签
-- ============================================================
UPDATE tags
SET
    is_enabled = 0,
    tag_type = 'ai'
WHERE
    tag_type IN ('domain', 'human');

-- ============================================================
-- Step 2: 删除不在新一级标签列表中的 father_tags
--   （FK ON DELETE CASCADE 会自动清理 documents_tags_rel 里 father_tag_id 的引用行）
-- ============================================================
DELETE FROM father_tags
WHERE
    tag_name NOT IN (
        '工会工作',
        '共青团工作',
        'CI工作',
        '舆情工作',
        '品牌宣传工作',
        '党委理论中心组学习工作',
        '企业文化工作',
        '意识形态工作',
        '党建工作'
    );

-- ============================================================
-- Step 3: UPSERT 9 个一级标签及其二级标签计数
-- ============================================================
INSERT INTO
    father_tags (tag_name, sub_tag_count)
VALUES ('工会工作', 7),
    ('共青团工作', 4),
    ('CI工作', 17),
    ('舆情工作', 15),
    ('品牌宣传工作', 13),
    (
        '党委理论中心组学习工作',
        1
    ),
    ('企业文化工作', 4),
    ('意识形态工作', 1),
    ('党建工作', 5)
ON DUPLICATE KEY UPDATE
    sub_tag_count = VALUES(sub_tag_count);

-- ============================================================
-- Step 4: UPSERT 67 个二级标签
--   — tag_type='human'、is_enabled=1、按一级标签绑定 father_tag
-- ============================================================

-- 4.1 工会工作 (7)
INSERT INTO
    tags (
        tag_name,
        tag_type,
        is_enabled,
        father_tag
    )
VALUES (
        '工会组织建设工作',
        'human',
        1,
        '工会工作'
    ),
    (
        '工会民主管理工作',
        'human',
        1,
        '工会工作'
    ),
    (
        '工会经济技术工作',
        'human',
        1,
        '工会工作'
    ),
    (
        '工会财务与经审工作',
        'human',
        1,
        '工会工作'
    ),
    (
        '工会女职工工作',
        'human',
        1,
        '工会工作'
    ),
    (
        '职工之家建设工作',
        'human',
        1,
        '工会工作'
    ),
    ('其他工会工作', 'human', 1, '工会工作')
ON DUPLICATE KEY UPDATE
    is_enabled = 1,
    tag_type = 'human',
    father_tag = VALUES(father_tag);

-- 4.2 共青团工作 (4)
INSERT INTO
    tags (
        tag_name,
        tag_type,
        is_enabled,
        father_tag
    )
VALUES (
        '团的组织建设工作',
        'human',
        1,
        '共青团工作'
    ),
    (
        '思想政治引领',
        'human',
        1,
        '共青团工作'
    ),
    (
        '服务青年发展',
        'human',
        1,
        '共青团工作'
    ),
    (
        '社会实践与志愿服务',
        'human',
        1,
        '共青团工作'
    )
ON DUPLICATE KEY UPDATE
    is_enabled = 1,
    tag_type = 'human',
    father_tag = VALUES(father_tag);

-- 4.3 CI工作 (17)
INSERT INTO
    tags (
        tag_name,
        tag_type,
        is_enabled,
        father_tag
    )
VALUES ('CI通用规范', 'human', 1, 'CI工作'),
    (
        'CI施工区外部形象展示',
        'human',
        1,
        'CI工作'
    ),
    (
        'CI施工区现场图牌',
        'human',
        1,
        'CI工作'
    ),
    (
        'CI施工区施工设备形象',
        'human',
        1,
        'CI工作'
    ),
    (
        'CI施工区安全防护形象',
        'human',
        1,
        'CI工作'
    ),
    ('CI办公区形象', 'human', 1, 'CI工作'),
    (
        'CI办公区会议室',
        'human',
        1,
        'CI工作'
    ),
    (
        'CI办公区办公室',
        'human',
        1,
        'CI工作'
    ),
    ('CI生活区临建', 'human', 1, 'CI工作'),
    ('CI生活区宿舍', 'human', 1, 'CI工作'),
    ('CI生活区食堂', 'human', 1, 'CI工作'),
    (
        'CI生活区卫浴区',
        'human',
        1,
        'CI工作'
    ),
    ('CI办公系统', 'human', 1, 'CI工作'),
    ('CI人员形象', 'human', 1, 'CI工作'),
    (
        'CI提升项目要求',
        'human',
        1,
        'CI工作'
    ),
    ('CI示范项目', 'human', 1, 'CI工作'),
    (
        'CI工作制度文件',
        'human',
        1,
        'CI工作'
    )
ON DUPLICATE KEY UPDATE
    is_enabled = 1,
    tag_type = 'human',
    father_tag = VALUES(father_tag);

-- 4.4 舆情工作 (15)
INSERT INTO
    tags (
        tag_name,
        tag_type,
        is_enabled,
        father_tag
    )
VALUES (
        '负面舆情案例',
        'human',
        1,
        '舆情工作'
    ),
    ('制度执行', 'human', 1, '舆情工作'),
    (
        '舆情应对口径',
        'human',
        1,
        '舆情工作'
    ),
    (
        '舆情等级类别',
        'human',
        1,
        '舆情工作'
    ),
    (
        '安全工伤类舆情管理',
        'human',
        1,
        '舆情工作'
    ),
    ('质量维保类', 'human', 1, '舆情工作'),
    (
        '文明施工环保类',
        'human',
        1,
        '舆情工作'
    ),
    ('工人讨薪类', 'human', 1, '舆情工作'),
    ('结算纠纷类', 'human', 1, '舆情工作'),
    (
        '拖欠工程款类',
        'human',
        1,
        '舆情工作'
    ),
    ('法律纠纷类', 'human', 1, '舆情工作'),
    ('违规处罚类', 'human', 1, '舆情工作'),
    ('员工投诉类', 'human', 1, '舆情工作'),
    ('消防类', 'human', 1, '舆情工作'),
    ('其他类', 'human', 1, '舆情工作')
ON DUPLICATE KEY UPDATE
    is_enabled = 1,
    tag_type = 'human',
    father_tag = VALUES(father_tag);

-- 4.5 品牌宣传工作 (13)
INSERT INTO
    tags (
        tag_name,
        tag_type,
        is_enabled,
        father_tag
    )
VALUES (
        '媒体报道类',
        'human',
        1,
        '品牌宣传工作'
    ),
    (
        'OA报道类',
        'human',
        1,
        '品牌宣传工作'
    ),
    (
        '微信报道类',
        'human',
        1,
        '品牌宣传工作'
    ),
    (
        '网站报道类',
        'human',
        1,
        '品牌宣传工作'
    ),
    (
        '报纸报道类',
        'human',
        1,
        '品牌宣传工作'
    ),
    (
        '视频报道类',
        'human',
        1,
        '品牌宣传工作'
    ),
    (
        '图片拍摄类',
        'human',
        1,
        '品牌宣传工作'
    ),
    (
        '人物报道类',
        'human',
        1,
        '品牌宣传工作'
    ),
    (
        '工程报道类',
        'human',
        1,
        '品牌宣传工作'
    ),
    (
        '会议活动报道类',
        'human',
        1,
        '品牌宣传工作'
    ),
    (
        '荣誉报道类',
        'human',
        1,
        '品牌宣传工作'
    ),
    (
        '宣传管理制度',
        'human',
        1,
        '品牌宣传工作'
    ),
    (
        '典型选树宣传制度',
        'human',
        1,
        '品牌宣传工作'
    )
ON DUPLICATE KEY UPDATE
    is_enabled = 1,
    tag_type = 'human',
    father_tag = VALUES(father_tag);

-- 4.6 党委理论中心组学习工作 (1)
INSERT INTO
    tags (
        tag_name,
        tag_type,
        is_enabled,
        father_tag
    )
VALUES (
        '党委理论中心组学习制度',
        'human',
        1,
        '党委理论中心组学习工作'
    )
ON DUPLICATE KEY UPDATE
    is_enabled = 1,
    tag_type = 'human',
    father_tag = VALUES(father_tag);

-- 4.7 企业文化工作 (4)
INSERT INTO
    tags (
        tag_name,
        tag_type,
        is_enabled,
        father_tag
    )
VALUES (
        '习近平文化思想',
        'human',
        1,
        '企业文化工作'
    ),
    (
        '中建信条',
        'human',
        1,
        '企业文化工作'
    ),
    (
        '十典九章',
        'human',
        1,
        '企业文化工作'
    ),
    (
        '先锋文化',
        'human',
        1,
        '企业文化工作'
    )
ON DUPLICATE KEY UPDATE
    is_enabled = 1,
    tag_type = 'human',
    father_tag = VALUES(father_tag);

-- 4.8 意识形态工作 (1)
INSERT INTO
    tags (
        tag_name,
        tag_type,
        is_enabled,
        father_tag
    )
VALUES (
        '意识形态工作',
        'human',
        1,
        '意识形态工作'
    )
ON DUPLICATE KEY UPDATE
    is_enabled = 1,
    tag_type = 'human',
    father_tag = VALUES(father_tag);

-- 4.9 党建工作 (5)
INSERT INTO
    tags (
        tag_name,
        tag_type,
        is_enabled,
        father_tag
    )
VALUES (
        '党的基本制度理论及相关要求',
        'human',
        1,
        '党建工作'
    ),
    (
        '党风廉政建设',
        'human',
        1,
        '党建工作'
    ),
    (
        '党员教育发展',
        'human',
        1,
        '党建工作'
    ),
    ('组织建设', 'human', 1, '党建工作'),
    (
        '党建工作责任制考核',
        'human',
        1,
        '党建工作'
    )
ON DUPLICATE KEY UPDATE
    is_enabled = 1,
    tag_type = 'human',
    father_tag = VALUES(father_tag);

COMMIT;

-- ============================================================
-- Step 5: 校验输出
-- ============================================================
SELECT '=== 刷新完成 ===' AS result;

SELECT COUNT(*) AS father_tags_count FROM father_tags;

SELECT tag_name, sub_tag_count
FROM father_tags
ORDER BY id;

SELECT COUNT(*) AS enabled_human_tags
FROM tags
WHERE
    tag_type = 'human'
    AND is_enabled = 1;

SELECT father_tag, COUNT(*) AS sub_count
FROM tags
WHERE
    tag_type = 'human'
    AND is_enabled = 1
GROUP BY
    father_tag
ORDER BY father_tag;

SELECT COUNT(*) AS disabled_tags
FROM tags
WHERE
    is_enabled = 0;
