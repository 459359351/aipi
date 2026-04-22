-- ============================================
-- 难度标签原地改名 (2026-04-22)
-- ============================================
-- 目的：把 tag_type='difficulty' 下的三条标签
--   基础 → 简单
--   进阶 → 一般
--   综合 → 困难
-- 保留原 tag_id，以便任何历史 question_tag_rel 绑定不失效。
--
-- 安全策略：
--   1) 事务内 SELECT ... FOR UPDATE 锁住三行，防止并发写入篡改
--   2) 事务内统计 question_tag_rel 对这三条 tag_id 的引用数到会话变量 @ref_count
--   3) 若 @ref_count > 0，三条 UPDATE 走 CASE 分支全部 no-op（保持原名）
--      若 @ref_count = 0，则完成改名
--   4) 末尾 SELECT 输出结果：成功提示或"中止+引用计数"提示
--   5) 幂等：若标签已是新名（简单/一般/困难），UPDATE 匹配 0 行不报错
--
-- 执行前建议：mysqldump tags question_tag_rel 作为兜底。

START TRANSACTION;

-- Step 1: 锁定旧三条标签（幂等：若已改名则匹配 0 行，无影响）
SELECT id, tag_name
FROM tags
WHERE
    tag_type = 'difficulty'
    AND tag_name IN (
        '基础',
        '进阶',
        '综合'
    ) FOR
UPDATE;

-- Step 2: 事务内统计 question_tag_rel 对旧三条标签的引用数
SELECT COUNT(*) INTO @ref_count
FROM question_tag_rel qtr
    JOIN tags t ON t.id = qtr.tag_id
WHERE
    t.tag_type = 'difficulty'
    AND t.tag_name IN (
        '基础',
        '进阶',
        '综合'
    );

-- Step 3: 条件改名（@ref_count > 0 时全部 no-op，保持原名）
UPDATE tags
SET
    tag_name = CASE
        WHEN @ref_count = 0 THEN '简单'
        ELSE '基础'
    END
WHERE
    tag_type = 'difficulty'
    AND tag_name = '基础';

UPDATE tags
SET
    tag_name = CASE
        WHEN @ref_count = 0 THEN '一般'
        ELSE '进阶'
    END
WHERE
    tag_type = 'difficulty'
    AND tag_name = '进阶';

UPDATE tags
SET
    tag_name = CASE
        WHEN @ref_count = 0 THEN '困难'
        ELSE '综合'
    END
WHERE
    tag_type = 'difficulty'
    AND tag_name = '综合';

COMMIT;

-- Step 4: 输出结果（成功或中止说明）
SELECT
    CASE
        WHEN @ref_count = 0 THEN '=== 难度标签改名完成 ==='
        ELSE CONCAT(
            '=== 中止：发现 ', @ref_count, ' 条 question_tag_rel 引用旧三条标签，未做改名。请人工检查绑定后重试 ==='
        )
    END AS result;

SELECT id, tag_name, tag_type, is_enabled
FROM tags
WHERE
    tag_type = 'difficulty'
ORDER BY id;
