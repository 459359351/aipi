-- 为 user_profiles 表新增 level（级别）字段
ALTER TABLE user_profiles ADD COLUMN level VARCHAR(64) NULL COMMENT '级别' AFTER position;

-- 初始化第一条用户画像
INSERT INTO user_profiles (user_id, department, position, level, interests)
VALUES ('肖', '组织部', '党务专员', '中级', '["党建"]')
ON DUPLICATE KEY UPDATE
  department = VALUES(department),
  position = VALUES(position),
  level = VALUES(level),
  interests = VALUES(interests);
