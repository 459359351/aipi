-- ============================================
-- tags 预设标签初始化（可重复执行）
-- ============================================
-- 说明：
-- 1) 依赖 tags 表已存在（建议先执行 init_tables.sql / migrate_tag_confirmation.sql）
-- 2) 通过 ON DUPLICATE KEY UPDATE 实现幂等

-- domain: 业务主题
INSERT INTO tags (tag_name, tag_type, is_enabled) VALUES
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
('共青团工作', 'domain', 1),
('意识形态工作', 'domain', 1),
('基层党建', 'domain', 1),
('党内监督', 'domain', 1)
ON DUPLICATE KEY UPDATE
  tag_type = VALUES(tag_type),
  is_enabled = GREATEST(is_enabled, VALUES(is_enabled));

-- chapter: 章节/条款类
INSERT INTO tags (tag_name, tag_type, is_enabled) VALUES
('总则', 'chapter', 1),
('第一章', 'chapter', 1),
('第二章', 'chapter', 1),
('第三章', 'chapter', 1),
('第四章', 'chapter', 1),
('第五章', 'chapter', 1),
('第六章', 'chapter', 1),
('附则', 'chapter', 1),
('第一条', 'chapter', 1),
('第二条', 'chapter', 1),
('第三条', 'chapter', 1),
('第四条', 'chapter', 1)
ON DUPLICATE KEY UPDATE
  tag_type = VALUES(tag_type),
  is_enabled = GREATEST(is_enabled, VALUES(is_enabled));

-- knowledge_type: 知识类型
INSERT INTO tags (tag_name, tag_type, is_enabled) VALUES
('定义', 'knowledge_type', 1),
('原则', 'knowledge_type', 1),
('流程', 'knowledge_type', 1),
('职责权限', 'knowledge_type', 1),
('时间节点', 'knowledge_type', 1),
('数字', 'knowledge_type', 1),
('禁止事项', 'knowledge_type', 1),
('制度要求', 'knowledge_type', 1),
('适用范围', 'knowledge_type', 1),
('考核标准', 'knowledge_type', 1),
('问责情形', 'knowledge_type', 1)
ON DUPLICATE KEY UPDATE
  tag_type = VALUES(tag_type),
  is_enabled = GREATEST(is_enabled, VALUES(is_enabled));

-- difficulty: 难度（可选）
INSERT INTO tags (tag_name, tag_type, is_enabled) VALUES
('简单', 'difficulty', 1),
('一般', 'difficulty', 1),
('困难', 'difficulty', 1)
ON DUPLICATE KEY UPDATE
  tag_type = VALUES(tag_type),
  is_enabled = GREATEST(is_enabled, VALUES(is_enabled));

SELECT 'tags 预设数据初始化完成' AS result;

