-- 题库数据库表结构
-- 生成时间: 2026-02-05 10:58:46
-- 说明：删除了 catalog_code 和 department_code 字段，选择题选项改为独立字段

CREATE TABLE `exam_records` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `user_id` INT NOT NULL,
  `phone` VARCHAR(20) NOT NULL,
  `bank_id` INT NOT NULL,
  `bank_id_range` VARCHAR(255), -- 新增字段：题库ID范围，如 "1-5" 或 "1,3,5"
  `exam_candidate_id` INT, -- 新增字段：关联到exam_candidates表的id字段
  `batch_id` INT, -- 新增字段：关联到assessment_batches表的id字段
  `title` VARCHAR(255),
  `info` TEXT,
  `bankname` VARCHAR(255),
  `bankstatus` ENUM('pending','completed','absent') DEFAULT 'pending' COMMENT '状态：待考/已完成/缺席',
  `start_time` DATE,
  `end_time` DATE,
  `correct_rate` DECIMAL(5,2),
  `answered_count` INT,
  `unanswered_count` INT,
  `incorrect_count` INT,
  `final_score` DECIMAL(6,2),
  `study_suggestion` TEXT,
  `record_type` ENUM('exam','history','score','analysis') NOT NULL COMMENT '记录类型：考试/历史/得分/分析',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_user_id` (`user_id`),
  INDEX `idx_phone` (`phone`),
  INDEX `idx_bank_id` (`bank_id`),
  INDEX `idx_record_type` (`record_type`),
  INDEX `idx_exam_candidate_id` (`exam_candidate_id`),
  INDEX `idx_batch_id` (`batch_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='考试相关记录';

-- 添加 bank_id_range 字段，用于存储题库ID范围
ALTER TABLE `assessment_batches`
ADD COLUMN `bank_id_range` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '题库ID范围，如 "1-5" 或 "1,3,5"' AFTER `end_date`;

-- 修改字段注释，使其与设计保持一致（保留原表注释）
ALTER TABLE `assessment_batches`
MODIFY COLUMN `title` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '考核主题（对应题库名称）';

-- 添加 user_id 字段，用于关联用户表
ALTER TABLE `exam_candidates`
ADD COLUMN `user_id` INT NOT NULL DEFAULT 0 COMMENT '用户ID，关联到users表' AFTER `phone`;

-- 添加 assigned_bank_ids 字段，用于存储分配给该考生的具体题库ID
ALTER TABLE `exam_candidates`
ADD COLUMN `assigned_bank_ids` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '分配给该考生的具体题库ID' AFTER `user_id`;

-- 添加索引，优化查询性能
ALTER TABLE `exam_candidates`
ADD INDEX `idx_user_id` (`user_id`) COMMENT '用户ID索引，加速按用户查询',
ADD INDEX `idx_phone_batch` (`phone`, `batch_id`) COMMENT '手机号和批次ID联合索引，加速按手机号和批次查询',
ADD INDEX `idx_user_status` (`user_id`, `status`) COMMENT '用户ID和状态联合索引，加速按用户和状态查询';


-- ================================
-- 1. 单选题表
-- ================================
DROP TABLE IF EXISTS `single_choice_questions`;
CREATE TABLE `single_choice_questions` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `question_stem` text NOT NULL COMMENT '试题题干',
  `score` tinyint(4) NOT NULL DEFAULT '1' COMMENT '分数',
  `difficulty` varchar(10) NOT NULL DEFAULT '低' COMMENT '难易度：低/中/高',
  `analysis` text COMMENT '试题解析',
  `answer` varchar(10) NOT NULL COMMENT '答案（A/B/C/D等）',
  `option_a` text NOT NULL COMMENT '选项A',
  `option_b` text NOT NULL COMMENT '选项B',
  `option_c` text NOT NULL COMMENT '选项C',
  `option_d` text NOT NULL COMMENT '选项D',
  `option_e` text NOT NULL COMMENT '选项E',
  `option_f` text NOT NULL COMMENT '选项F',
  `option_g` text NOT NULL COMMENT '选项G',
  `option_h` text NOT NULL COMMENT '选项H',
  `option_i` text NOT NULL COMMENT '选项I',
  `option_j` text NOT NULL COMMENT '选项J',
  `primary_tag` varchar(100) DEFAULT NULL COMMENT '一级标签',
  `secondary_tag` varchar(100) DEFAULT NULL COMMENT '二级标签 多个标签用逗号分隔，如：党员,干部,积极分子',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_difficulty` (`difficulty`),
  KEY `idx_primary_tag` (`primary_tag`),
  KEY `idx_secondary_tag` (`secondary_tag`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='单选题表';

-- ================================
-- 2. 多选题表（含不定项选择题）
-- ================================
DROP TABLE IF EXISTS `multiple_choice_questions`;
CREATE TABLE `multiple_choice_questions` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `question_stem` text NOT NULL COMMENT '试题题干',
  `question_type` varchar(20) NOT NULL COMMENT '试题类型：多选/不定项',
  `score` tinyint(4) NOT NULL DEFAULT '1' COMMENT '分数',
  `difficulty` varchar(10) NOT NULL DEFAULT '低' COMMENT '难易度：低/中/高',
  `analysis` text COMMENT '试题解析',
  `answer` varchar(50) NOT NULL COMMENT '答案（如：ABC/ABCD）',
  `option_a` text NOT NULL COMMENT '选项A',
  `option_b` text NOT NULL COMMENT '选项B',
  `option_c` text NOT NULL COMMENT '选项C',
  `option_d` text NOT NULL COMMENT '选项D',
  `option_e` text NOT NULL COMMENT '选项E',
  `option_f` text NOT NULL COMMENT '选项F',
  `option_g` text NOT NULL COMMENT '选项G',
  `option_h` text NOT NULL COMMENT '选项H',
  `option_i` text NOT NULL COMMENT '选项I',
  `option_j` text NOT NULL COMMENT '选项J',
  `primary_tag` varchar(100) DEFAULT NULL COMMENT '一级标签',
  `secondary_tag` varchar(100) DEFAULT NULL COMMENT '二级标签 多个标签用逗号分隔，如：党员,干部,积极分子',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_question_type` (`question_type`),
  KEY `idx_difficulty` (`difficulty`),
  KEY `idx_primary_tag` (`primary_tag`),
  KEY `idx_secondary_tag` (`secondary_tag`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='多选题表';

-- ================================
-- 3. 判断题表
-- ================================
DROP TABLE IF EXISTS `true_false_questions`;
CREATE TABLE `true_false_questions` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `question_stem` text NOT NULL COMMENT '试题题干',
  `score` tinyint(4) NOT NULL DEFAULT '1' COMMENT '分数',
  `difficulty` varchar(10) NOT NULL DEFAULT '低' COMMENT '难易度：低/中/高',
  `analysis` text COMMENT '试题解析',
  `answer` varchar(10) NOT NULL COMMENT '答案（对/错 或 √/×）',
  `primary_tag` varchar(100) DEFAULT NULL COMMENT '一级标签',
  `secondary_tag` varchar(100) DEFAULT NULL COMMENT '二级标签 多个标签用逗号分隔，如：党员,干部,积极分子',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_difficulty` (`difficulty`),
  KEY `idx_primary_tag` (`primary_tag`),
  KEY `idx_secondary_tag` (`secondary_tag`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='判断题表';

-- ================================
-- 4. 填空题表
-- ================================
DROP TABLE IF EXISTS `fill_in_blank_questions`;
CREATE TABLE `fill_in_blank_questions` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `question_stem` text NOT NULL COMMENT '试题题干',
  `score` tinyint(4) NOT NULL DEFAULT '1' COMMENT '分数',
  `difficulty` varchar(10) NOT NULL DEFAULT '低' COMMENT '难易度：低/中/高',
  `analysis` text COMMENT '试题解析',
  `answer` text NOT NULL COMMENT '答案（可能多个答案，用分号分隔）',
  `primary_tag` varchar(100) DEFAULT NULL COMMENT '一级标签',
  `secondary_tag` varchar(100) DEFAULT NULL COMMENT '二级标签 多个标签用逗号分隔，如：党员,干部,积极分子',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` timestamp NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_difficulty` (`difficulty`),
  KEY `idx_primary_tag` (`primary_tag`),
  KEY `idx_secondary_tag` (`secondary_tag`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='填空题表';



-- ================================
-- 导入数据
-- ================================

INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('“三重一大”事项不包括以下哪一项？', '1', '低', '', 'D', '重大决策', '重要人事任免', '大额度资金运作', '一般性财务支出', '', '', '', '', '', '', '企业战略与经营管理', '企业管理', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('“三重一大”等重要事项在决策前必须经过哪个组织的前置研究？', '1', '低', '', 'D', '监事会', '董事会', '经理层', '党委', '', '', '', '', '', '', '企业战略与经营管理', '企业管理', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中央八项规定强调要改进哪一项工作？', '1', '低', '', 'B', '增加会议活动', '精简文件简报', '放松出访限制', '放松新闻报道', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('“四个意识”不包括以下哪一项？', '1', '低', '', 'B', '政治意识', '民主意识', '大局意识', '看齐意识', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建集团“一个提高”指的是提高什么？', '1', '低', '', 'A', '政治站位', '经济效益', '管理水平', '企业文化', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建集团“六个塑强”中，不包括以下哪一项？', '1', '低', '', 'B', '塑强房建首位优势', '塑强国际品牌优势', '塑强设计领先优势', '塑强基建支柱优势', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局先锋文化的精神内核是什么？', '1', '低', '', 'A', '忠诚担当、使命必达', '品质为先、时代争锋', '团结协作、共创辉煌', '开拓创新、锐意进取', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局“155大党建工作格局”中的第一个“5”指的是什么？', '1', '低', '', 'B', '总部党支部五项重点工作', '两级党组织要全面履行五项职能', '项目党支部五个价值创造点', '党建工作五个基本原则', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局五公司“鲁班文化”中的“担当”不包括以下哪一项？', '1', '低', '', 'D', '政治担当', '责任担当', '业务担当', '文化担当', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建集团“166”战略举措中的“六个专项”不包括以下哪一项？', '1', '低', '', 'C', '深化巡视整改', '加强科技创新', '提升员工福利', '狠抓安全生产专项行动', '', '', '', '', '', '', '企业战略与经营管理', '企业管理', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局“1135”战略体系中的“五个关键路径”不包括以下哪一项？', '1', '低', '', 'D', '推进国内国外两个市场“1+3”产业发展战略', '推进项目管理三大建设和价值创造能力建设', '推进治理体系建设和公司化建设', '推进国际化战略', '', '', '', '', '', '', '企业战略与经营管理', '企业管理', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局“一最五领先”战略目标中的“一最”指的是什么？', '1', '低', '', 'A', '成为中国建筑旗下最具核心竞争力的高质量发展排头兵', '成为中国建筑旗下最具国际竞争力的核心子企业', '成为中国建筑旗下品牌美誉度最高的全产业链企业', '成为中国建筑旗下规模最大的基础设施投资建设集团', '', '', '', '', '', '', '企业战略与经营管理', '企业管理', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局“五力并举”战略路径中，不包括以下哪一项？', '1', '低', '', 'C', '提高党建引领力', '提高产业竞争力', '提高市场占有率', '提高企业治理力', '', '', '', '', '', '', '企业战略与经营管理', '企业管理', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局五公司“11336”战略思想中的“三个驱动”不包括以下哪一项？', '1', '低', '', 'D', '转型驱动', '创新驱动', '文化驱动', '市场驱动', '', '', '', '', '', '', '企业战略与经营管理', '企业管理', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记指出，中国特色社会主义最本质的特征是（ ）。', '1', '低', '', 'B', 'A. 人民当家作主', 'B. 中国共产党领导', 'C. 全面依法治国', 'D. 以人民为中心', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记强调，江山就是人民、人民就是江山，打江山、守江山，守的是（ ）。', '1', '低', '', 'A', 'A. 人民的利益', 'B. 人民的信任', 'C. 人民的心', 'D. 人民的拥护', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记提出新时代党的建设总要求，以党的（ ）统领党的建设各项工作。', '1', '低', '', 'B', 'A. 组织建设', 'B. 政治建设', 'C. 思想建设', 'D. 纪律建设', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记指出，思想建设是党的（ ）建设。', '1', '低', '', 'A', 'A. 基础性', 'B. 根本性', 'C. 保障性', 'D. 创新性', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记强调，党风问题关系执政党的（）。', '1', '低', '', 'C', 'A. 形象', 'B. 兴衰成败', 'C. 生死存亡', 'D. 事业发展', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记指出，坚持和加强党的全面领导，必须健全（ ）的党的领导制度体系。', '1', '低', '', 'A ', 'A. 总揽全局、协调各方', 'B. 统筹兼顾、上下联动', 'C. 民主集中、科学决策', 'D. 高效执行、监督有力', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记强调，要以伟大（ ）引领伟大社会革命。', '1', '低', '', 'A', 'A. 自我革命', 'B. 思想革命', 'C. 社会变革', 'D. 组织建设', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记指出，要提高各级党组织和党员干部（ ）、政治领悟力、政治执行力。', '1', '低', '', 'A', 'A. 政治判断力', 'B. 政治领导力', 'C. 政治凝聚力', 'D. 政治向心力', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记强调，要坚持不懈用（ ）凝心铸魂。 ', '1', '低', '', 'A', 'A. 新时代中国特色社会主义思想', 'B. 马克思主义基本原理', 'C. 中国特色社会主义理论体系', 'D. 党的创新理论', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记指出，好干部要做到信念坚定、为民服务、勤政务实、敢于担当、（ ）。', '1', '低', '', 'A', 'A. 清正廉洁', 'B. 勇于创新', 'C. 善于学习', 'D. 团结协作', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记指出，作风问题本质上是（ ）问题。', '1', '低', '', 'B', 'A. 纪律', 'B. 党性', 'C. 思想', 'D. 制度', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记强调，加强（ ）是全面从严治党的治本之策。', '1', '低', '', 'A', 'A. 纪律建设', 'B. 制度建设', 'C. 作风建设', 'D. 组织建设', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES (' 习近平总书记强调，要坚持一切为了人民、一切（ ）人民。  ', '1', '低', '', 'A ', 'A. 依靠', 'B. 服务', 'C. 惠及', 'D. 引领', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记指出，要站稳人民立场、把握人民愿望、尊重人民创造、（ ）。', '1', '低', '', 'C', 'A. 满足人民需求', 'B. 解决人民问题', 'C. 集中人民智慧', 'D. 保障人民权益', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记强调，要坚持把（ ）作为奋斗目标。 ', '1', '低', '', 'B', 'A. 实现中华民族伟大复兴', 'B. 人民对美好生活的向往', 'C. 全面建成小康社会', 'D. 建设社会主义现代化强国', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记强调，要以（ ）促进伟大自我革命。   ', '1', '低', '', 'A', 'A. 伟大社会革命', 'B. 伟大斗争', 'C. 伟大事业', 'D. 伟大梦想', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记指出，要深入实施新时代（ ）战略。 ', '1', '低', '', 'B', 'A. 创新驱动发展', 'B.人才强国', 'C. 科教兴国', 'D. 乡村振兴', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记强调，要坚持（ ），突出把好政治关、廉洁关。', '1', '低', '', 'A', 'A. 把政治标准放在首位', 'B. 把能力标准放在首位', 'C. 把业绩标准放在首位', 'D. 把道德标准放在首位', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记强调，党的建设要以（ ）为统领。', '1', '低', '', 'B', 'A.党的思想建设', 'B.党的政治建设', 'C. 党的组织建设', 'D. 党的作风建设', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES (' 习近平总书记指出，全面推进党的建设新的伟大工程，要以（ ）为主线。', '1', '低', '', 'D', 'A.加强党的制度建设、反腐倡廉建设', 'B. 加强党的思想建设、组织建设', 'C. 加强党的作风建设、纪律建设', 'D. 加强党的长期执政能力建设、先进性和纯洁性建设', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记强调，要不断提高党的建设（ ）水平。', '1', '低', '', 'D', 'A.现代化', 'B. 规范化', 'C. 制度化', 'D.科学化', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记指出，要以（ ）为着力点，全面推进党的建设。', '1', '低', '', 'A', 'A. 调动全党积极性、主动性、创造性', 'B. 加强党的基层组织建设', 'C. 培养选拔优秀干部', 'D. 加强党的纪律建设', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记指出，要把（ ）贯穿党的建设全过程和各方面。', '1', '低', '', 'B', 'A.  以人民为中心', 'B. 党的领导', 'C. 全面从严治党', 'D. 新发展理念', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记指出，要以（ ）为根本遵循，全面加强党的纪律建设。', '1', '低', '', 'A', 'A. 党章', 'B. 宪法', 'C. 党纪党规', 'D. 党的制度', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记强调，要一体推进（ ），坚决打赢反腐败斗争攻坚战持久战。', '1', '低', '', 'A', 'A. 不敢腐、不能腐、不想腐', 'B. 不敢贪、不能贪、不想贪', '不敢乱、不能乱、不想乱', 'D. 不敢违、不能违、不想违', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记指出，要加强（ ）建设，锻造堪当民族复兴重任的高素质干部队伍。', '1', '低', '', 'A ', 'A. 干部队伍', 'B. 人才队伍', 'C. 党员队伍', 'D. 基层队伍', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记强调，要增强党组织政治功能和组织功能，把基层党组织建设成为（ ）的坚强战斗堡垒。', '1', '低', '', 'A', 'A. 宣传党的主张、贯彻党的决定、领导基层治理、团结动员群众、推动改革发展', 'B. 教育党员、管理党员、监督党员、组织群众、宣传群众', 'C. 凝聚人心、服务群众、促进和谐、推动发展、维护稳定', 'D. 政治引领、组织动员、服务群众、促进和谐、推动改革', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记指出，要完善党的（ ）制度规范体系。', '1', '低', '', 'A', 'A. 自我革命', 'B. 建设发展', 'C. 监督管理', 'D. 组织建设', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记强调，要坚持（ ）、理论强党。', '1', '低', '', 'D', 'A. 纪律建党', 'B. 组织建党', 'C. 制度建党', 'D. 思想建党', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记指出，要不断严密上下贯通、（ ）的组织体系。', '1', '低', '', 'C', 'A.运转高效', 'B. 领导有方', 'C.执行有力', 'D. 协调顺畅', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记强调，要巩固拓展（ ）成果，持之以恒正风肃纪。', '1', '低', '', 'D', 'A. 党的群众路线教育实践活动', 'B. 不忘初心、牢记使命主题教育', 'C. 党史学习教育', 'D. 以上都是', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记强调，跳出治乱兴衰历史周期率的第二个答案是（ ）。', '1', '低', '', 'B', 'A. 人民监督政府', 'B. 自我革命', 'C. 民主协商', 'D. 全面从严治党', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中国共产党的最高理想和最终目标是（ ）。', '1', '低', '', 'C', 'A. 实现社会主义现代化', 'B. 实现中华民族伟', 'C. 实现共产主义', 'D. 全面建成小康社会', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中国共产党以马克思列宁主义、毛泽东思想、邓小平理论、“三个代表”重要思想、科学发展观、（ ）作为自己的行动指南。', '1', '低', '', 'B', 'A. 新时代中国特色社会主义思想', 'B. 习近平新时代中国特色社会主义思想', 'C. 中国特色社会主义理论体系', 'D. 习近平新时代中国特色社会主义理论', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党章规定，发展党员，必须把（ ）放在首位，经过党的支部，坚持个别吸收的原则。', '1', '低', '', 'A', 'A. 政治标准', 'B. 思想标准', 'C. 作风标准', 'D. 组织标准', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党的基层委员会、总支部委员会、支部委员会每届任期（ ）。', '1', '低', '', 'A', 'A. 三年至五年', 'B. 两年或三年', 'C. 三年', 'D. 五年', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES (' 党章规定，党员如果没有正当理由，连续（ ）不参加党的组织生活，或不交纳党费，或不做党所分配的工作，就被认为是自行脱党。', '1', '低', '', 'B', 'A. 三个月', 'B. 六个月', 'C. 九个月', 'D. 一年', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党在任何时候都把（ ）放在第一位，同群众同甘共苦，保持最密切的联系，坚持权为民所用、情为民所系、利为民所谋，不允许任何党员脱离群众，凌驾于群众之上。', '1', '低', '', 'C', 'A. 集体利益', 'B. 党的利益', 'C. 群众利益', 'D. 干部利益', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党的基层组织是党在社会基层组织中的（ ），是党的全部工作和战斗力的基础。', '1', '低', '', 'B', 'A. 领导核心', 'B. 战斗堡垒', 'C. 坚强核心', 'D. 中坚力量', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党按照（ ）的原则选拔干部。', '1', '低', '', 'D', 'A. 德才兼备、以德为先', 'B. 五湖四海、任人唯贤', 'C. 事业为上、公道正派', 'D. 以上都是', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('预备党员的预备期为（ ）。', '1', '低', '', 'B', 'A. 半年', 'B. 一年', 'C. 一年半', 'D. 两年', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('预备党员的权利，除了没有（ ）、选举权和被选举权以外，也同正式党员一样。', '1', '低', '', 'A', 'A. 表决权', 'B. 建议权', 'C. 申诉权', 'D. 发言权', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党的民主集中制的基本原则之一是“四个服从”，即党员个人服从党的组织，（ ），下级组织服从上级组织，全党各级组织和全体党员服从党的全国代表大会和中央委员会。 ', '1', '低', '', 'B', 'A. 党委委员服从党委书记', 'B. 少数服从多数', 'C. 普通党员服从党组织书记', 'D. 以上都不对', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('《中国共产党党徽党旗条例》规定，党徽图案一般使用（ ）颜色。', '1', '低', '', 'C', 'A. 红白', 'B. 红黄', 'C.金红', 'D. 金银', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目党支部组织生活会一般（ ）召开一次。  ', '1', '低', '', 'D', 'A. 每月', 'B. 每季度', 'C. 每半年', 'D. 每年', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党徽应当按照（ ）所附的中国共产党党徽制法说明制作。 ', '1', '低', '', 'B', 'A. 《中国共产党章程》', 'B. 《中国共产党党徽党旗条例》', 'C. 《关于新形势下党内政治生活的若干准则》', 'D. 《中国共产党纪律处分条例》', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目党支部“三会一课”中，“支部党员大会”一般每（ ）召开一次。  ', '1', '低', '', 'B', 'A. 月', 'B. 季度', 'C. 半年', 'D. 年', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目党支部发展党员，确定入党积极分子后，培养联系人一般至少（ ）与入党积极分子进行一次谈话。    ', '1', '低', '', 'C', 'A. 每月', 'B. 每两月', 'C. 每季度', 'D. 每半年', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目党支部主题党日活动，一般每月固定（ ）天。 ', '1', '低', '', 'A', 'A. 1', 'B. 2', 'C. 3', 'D. 4', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目党支部开展组织生活会，党员之间要进行（ ）。', '1', '低', '', 'C', 'A. 自我批评', 'B. 相互批评', 'C. 自我批评与相互批评', 'D. 查摆问题', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党组织的作用是“把方向”“管大局”，（   ）', '1', '低', '', 'D', '定战略', '作决策', '防风险', '保落实', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('国有企业党组织必须坚持和加强党的全面领导，坚持党要管党、全面从严治党，突出（  ），提升组织力。', '1', '低', '', 'B', '政治引领', '政治功能', '经济建设', '组织建设', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部（党总支）书记一般应当有（  ）以上党龄。', '1', '低', '', 'D', '1年', '2年', '3年', '5年', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('基层党组织应当严格执行（  ）制度，届满按期进行换届选举。', '1', '低', '', 'A', '任期', '选举', '民主', '监督', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('国有企业党组织履行党的建设主体责任，书记履行第一责任人职责，（  ）履行直接责任。', '1', '低', '', 'A', '副书记', '纪委书记', '组织委员', '宣传委员', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('国有企业基层党组织以党的（  ）为统领。', '1', '低', '', 'B', '思想建设', '政治建设', '组织建设', '作风建设', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('国有企业党员人数（  ）以上、100 人以下的，设立党的总支部委员会', '1', '低', '', 'D', '10人', '20人', '30人', '50人', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('正式党员不足 7 人的党支部，（  ）。', '1', '低', '', 'A', '不设支部委员会，设 1 名书记，必要时可设 1 名副书记', '设支部委员会，设 1 名书记', '设支部委员会，设 1 名书记，1 名副书记', '不设支部委员会，设 1 名书记', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('设立党支部的国有企业，正式党员（  ）人以上的，党支部设立支部委员会。', '1', '低', '', 'C', '3', '5', '7', '9', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('国有企业基层党组织应当严格执行党的组织生活制度，认真开展（  ）等活动。', '1', '低', '', 'D', '主题党日', '党员活动日', '民主评议党员', '以上都是', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('国有企业基层党组织要按照规定，做好（  ）等工作，保障党员权利。', '1', '低', '', 'D', '党员发展', '党员表彰', '党员处分', '以上都是', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('《中国共产党基层组织选举工作条例》规定，基层党组织设立的委员会委员候选人的差额为应选人数的（ ）', '1', '低', '', 'C', '0.1', '0.15', '0.2', '0.3', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('某项目党支部选举，选举收回的选票数，（ ）投票人数，选举有效。', '1', '低', '', 'D', '等于', '少于', '多于', '等于或少于', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('某分公司党总支委员会的书记、副书记选举产生后，应报（ ）批准。
', '1', '低', '', 'A', '上级党委', '上级组织部门', '上级纪委', '本级党员大会', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('基层项目党支部委员会每届任期一般为（ ）年。', '1', '低', '', 'B', '2', '3', '4', '5', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('基层党组织召开党员大会进行选举，有选举权的到会人数超过应到会人数的（ ），会议有效。', '1', '低', '', 'D', '二分之一', '三分之二', '四分之三', '五分之四', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('基层党组织委员会委员在任期内出缺，一般应当召开（ ）补选。', '1', '低', '', 'A', '党员大会', '党代表大会', '支部委员会', '党小组会', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('基层党组织选举中，监票人由（ ）从不是候选人的党员中推选，经党员大会或党员代表大会表决通过。', '1', '低', '', 'C', '支部委员会', '上级党组织指定', '全体党员', '党小组推荐', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('基层党组织选举时，被选举人获得的赞成票超过（ ）的半数，始得当选。', '1', '低', '', 'A', '实到会有选举权人数', '应到会有选举权人数', '实到会人数', '应到会人数', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('基层党组织选举中，选举大会结束后，新当选的党的委员会和纪律检查委员会应分别召开（ ）会议，等额选举产生书记、副书记。', '1', '低', '', 'A', '全体委员', '常委', '党员代表', '党小组', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('基层党组织选举时，选举人对候选人可以投赞成票，可以投不赞成票，也可以弃权。投不赞成票者（ ）另选他人。', '1', '低', '', 'B', '不可以', '可以', '根据情况决定', '经过大会同意后可以', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('基层党组织选举中，选举大会进行选举时，被选举人获得的赞成票超过（ ）的半数，始得当选。', '1', '低', '', 'C', '实到会人数', '应到会人数', '实到会有选举权人数', '应到会有选举权人数', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部党员大会一般（ ）召开 1 次。', '1', '低', '', 'B', '每月', '每季度', '每半年', '每年', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部委员会会议一般（ ）召开 1 次。', '1', '低', '', 'A', '每月', '每季度', '每半年', '每年', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党小组会一般（ ）召开 1 次。', '1', '低', '', 'A', '每月', '每季度', '每半年', '每年', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党课一般（ ）至少组织 1 次。', '1', '低', '', 'B', '每月', '每季度', '每半年', '每年', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('有正式党员（ ）人以上的，应当成立党支部。', '1', '低', '', 'A', '3', '5', '7', '10', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('正式党员不足 3 人的单位，应当按照地域相邻、行业相近、规模适当、便于管理的原则，成立（ ）。', '1', '低', '', 'A', '联合党支部', '临时党支部', '流动党员党支部', '功能型党支部', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部党员人数一般不超过（ ）人。', '1', '低', '', 'B', '30', '50', '70', '100', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('基层单位党支部委员会一般每届任期（ ）年。', '1', '低', '', 'B', '2', '3', '4', '5', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部的基本任务之一是，对党员进行教育、管理、监督和服务，突出政治教育，提高党员素质，坚定理想信念，增强党性，严格党的组织生活，开展（ ），维护和执行党的纪律，监督党员切实履行义务，保障党员的权利不受侵犯。', '1', '低', '', 'A', '批评和自我批评', '谈心谈话', '民主评议党员', '党性分析', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部的基本任务之一是，密切联系群众，向群众宣传党的政策，经常了解群众对党员、党的工作的批评和意见，了解群众诉求，维护群众的（ ），做好群众的思想政治工作，凝聚广大群众的智慧和力量。', '1', '低', '', 'A', '正当权利和利益', '所有利益', '合法权益', '根本利益', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部党员大会的职权不包括（ ）。', '1', '低', '', 'B', '讨论和决定党支部重要事项', '选举上级党代表大会代表', '听取和审查党支部委员会的工作报告', '讨论和决定接收预备党员和预备党员转正、延长预备期或者取消预备党员资格', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部委员会由（ ）选举产生。', '1', '低', '', 'A', '党支部党员大会', '上级党组织', '党支部书记指定', '全体党员推荐', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部书记一般应当具有（ ）年以上党龄。', '1', '低', '', 'A', '1', '2', '3', '4', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('有（ ）名以上正式党员的党支部，应当设立党支部委员会。', '1', '低', '', 'C', '3', '5', '7', '10', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部委员会一般设委员（ ）人。', '1', '低', '', 'B', '3 至 5', '3 至 7', '5 至 7', '5 至 9', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('对不适宜担任党支部书记、副书记和委员职务的，上级党组织应当及时作出（ ）。', '1', '低', '', 'B', '撤职决定', '免职或调整决定', '警告处分', '留党察看处分', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部党员大会议题提交表决前，应当经过充分讨论。表决必须有（ ）以上有表决权的党员到会方可进行，赞成人数超过应到会有表决权的党员的（ ）为通过。', '1', '低', '', 'A', '半数；半数', '三分之二；半数', '半数；三分之二', '三分之二；三分之二', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部应当严格执行党的组织生活制度，经常、认真、严肃地开展批评和自我批评，增强党内政治生活的（ ）。', '1', '低', '', 'A', '政治性、时代性、原则性、战斗性', '政治性、思想性、原则性、战斗性', '政治性、时代性、纪律性、战斗性', '政治性、时代性、原则性、组织性', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部应当组织党员按期参加党员大会、党小组会和上党课，定期召开党支部委员会会议。“三会一课” 应当突出政治学习和教育，突出党性锻炼，以（ ）为主要内容。', '1', '低', '', 'D', '党的理论教育', '党章党规党纪教育', '党的创新理论学习', '学习党章党规、学习系列讲话', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部应当经常开展谈心谈话。党支部委员之间、党支部委员和党员之间、党员和党员之间，每年谈心谈话一般不少于（ ）次。', '1', '低', '', 'A', '1', '2', '3', '4', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部一般（ ）开展 1 次民主评议党员。', '1', '低', '', 'D', '每月', '每季度', '每半年', '每年', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('流动党员党支部，组织流动党员开展政治学习，过好组织生活，进行民主评议，引导党员履行党员义务，行使党员权利，充分发挥作用。对组织关系不在本党支部的流动党员民主评议等情况，应当通报其（ ）。', '1', '低', '', 'A', '原所在党支部', '上级党组织', '工作单位党组织', '居住地党组织', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部应当注重分析党员思想状况和心理状态，党组织负责人应当经常同党员谈心谈话，有针对性地做好思想政治工作。对家庭发生重大变故和出现重大困难、身心健康存在突出问题等情况的党员，党支部书记应当帮助做好（ ）。', '1', '低', '', 'C', '心理疏导', '帮扶慰问', '思想引导和心理疏导', '生活救助', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部应当对入党积极分子进行教育和培养，做好经常性的发展党员工作，把（ ）放在首位，严格程序、严肃纪律，发展政治品质纯洁的党员。', '1', '低', '', 'A', '政治标准', '思想标准', '道德标准', '工作标准', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部书记、副书记和委员出现空缺，应当及时进行补选。确有必要时，上级党组织可以指派（ ）。', '1', '低', '', 'D', '党支部书记', '党支部副书记', '党支部委员', '党支部书记、副书记或者委员', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部的成立，一般由（ ）提出申请，所在乡镇（街道）或者单位基层党委召开会议研究决定并批复，批复时间一般不超过 1 个月。', '1', '低', '', 'D', '基层党委', '上级党委组织部门', '党员', '符合条件的党员', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部的调整和撤销，一般由党支部报（ ）批准，也可以由基层党委直接作出决定，并报上级党委组织部门备案。', '1', '低', '', 'B', '上级党委组织部门', '所在党组织或者单位基层党组织', '上级党委', '县级党委组织部门', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('总部部门党支部着力推动的 “五项重点工作”，项目党支部充分发挥的是（ ）', '1', '低', '', 'B', '“四个价值创造点” 作用', '“五个价值创造点” 作用', '“六个价值创造点” 作用', '“七个价值创造点” 作用', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部设置落实 “四同步”“四对接” 要求，其中 “四同步” 不包括（ ）', '1', '低', '', 'D', '同步建立党的组织', '同步配备党组织负责人', '同步开展党的工作', '同步进行党员教育', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('正式党员超过 3 人且相对固定的单位应（ ）', '1', '低', '', 'B', '与其他单位成立联合党支部', '单独成立党支部', '设立党总支', '等待上级安排', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('为期 6 个月以上的工程、工作项目等，符合条件的，应（ ）', '1', '低', '', 'B', '成立联合党支部', '单独成立党支部', '设立党总支', '不设立党组织', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('正式党员不足 3 人的单位，应当（ ）', '1', '低', '', 'B', '单独成立党支部', '与其他单位成立联合党支部', '设立临时党支部', '等待党员人数增加后再成立党支部', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('联合党支部覆盖单位一般不超过（ ）', '1', '低', '', 'C', '3 个', '4 个', '5个', '6个', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部的成立，一般由基层单位提出申请，上级党委召开会议研究决定并批复，批复时间一般不超过（ ）', '1', '低', '', 'B', '半个月', '1个月', '2个月', '3个月', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('上级党委审批同意后，基层单位召开党员大会选举产生（ ）', '1', '低', '', 'B', '党支部书记', '党支部委员会', '党支部副书记', '党小组组长', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('有正式党员 7 人以上的党支部，设立党支部委员会，党支部委员会由（ ）组成。', '1', '低', '', 'A', '3 至 5 人', '3 至 7 人', '5 至 7 人', '5 至 9 人', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党总支委员会一般设委员（ ）', '1', '低', '', 'C', '3 至 5 人', '3 至 7 人', '5 至 7 人', '5 至 9 人', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部书记一般由符合条件的本单位（ ）担任。', '1', '低', '', 'A', '行政第一负责人', '行政副职', '普通党员', '工会主席', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部书记须由具有（ ）以上党龄的优秀党员担任。', '1', '低', '', 'B', '半年', '1年', '2年', '3年', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部书记、副书记一般由（ ）选举产生。', '1', '低', '', 'B', '党支部党员大会', '党支部委员会会议', '上级党委任命', '职工大会', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部委员会每届任期一般为（ ）', '1', '低', '', 'B', '2年', '3年', '4年', '5年', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部书记、副书记、委员出现空缺，一般应当召开（ ）及时补选。', '1', '低', '', 'B', '党支部委员会会议', '党支部党员大会', '党小组会', '职工大会', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('换届选举时，有选举权的到会党员数超过应到会有选举权党员数的（ ）方可开会。', '1', '低', '', 'D', '二分之一', '三分之二', '五分之三', '五分之四', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('被选举人获得的赞成票超过（ ）的半数，始得当选。', '1', '低', '', 'B', '应到会有选举权的党员数', '实到会有选举权的党员数', '全体党员数', '参加会议的党员数', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部党员大会是党支部的议事决策机构，一般每（ ）召开 1 次。', '1', '低', '', 'B', '月', '季度', '半年', '年', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部委员会会议一般每月召开（ ）次。', '1', '低', '', 'A', '1', '2', '3', '4', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党小组会一般每月召开（ ）次。', '1', '低', '', 'A', '1', '2', '3', '4', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党课以（ ）为宜。', '1', '低', '', 'B', '分散学习', '集中学习', '个人自学', '网络自学', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部每月相对固定（ ）天开展主题党日。', '1', '低', '', 'A', '1', '2', '3', '4', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('民主评议党员可以结合（ ）一并进行。', '1', '低', '', 'A', '组织生活会', '党员大会', '党支部委员会会议', '党小组会', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部委员之间、党支部委员和党员之间、党员和党员之间，每年谈心谈话一般不少于（ ）次。', '1', '低', '', 'A', '1', '2', '3', '4', '', '', '', '', '', '', '党风廉政建设', '党建廉政', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('根据《中国共产党发展党员工作细则》及文档内容，入党申请人应当向（ ）党组织提出入党申请。', '1', '低', '', 'B', '居住地所在', '工作所在单位', '父母所在单位', '任意党组织', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('在入党申请人中确定入党积极分子，应当采取（ ）方式产生人选。', '1', '低', '', 'A', '党员推荐、群团组织推优', '领导指定', '个人自荐', '随机抽取', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('确定入党积极分子，需由（ ）研究决定。', '1', '低', '', 'B', '支部党员大会', '支部委员会', '上级党委', '党小组', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('入党积极分子确定后，要报（ ）备案。', '1', '低', '', 'A', '总部党总支、各分公司 / 事业部党委 （党总支） 及上一级党委', '仅上级党委', '仅本单位党支部', '仅总部党总支', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('对入党积极分子的培养教育考察期需满（ ），基本具备党员条件的，才可列为发展对象。', '1', '低', '', 'B', '6 个月', '1 年', '2 年', '3 年', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('发展对象需经（ ）预审合格后，才能进入下一步接收预备党员程序。', '1', '低', '', 'A', '各分公司 / 事业部党委 （党总支）', '公司党委', '上级党委', '党支部', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('接收预备党员时，需经（ ）讨论，采取无记名投票方式表决。', '1', '低', '', 'C', '支部委员会', '党小组会', '党员大会', '上级党委会议', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('发展对象未来（ ）内将离开工作、学习单位的，一般不办理接收预备党员的手续。', '1', '低', '', 'C', '1个月', '2个月', '3个月', '4个月', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('预备党员预备期从（ ）算起。', '1', '低', '', 'B', '上级党委批准之日', '支部党员大会通过之日', '确定为预备党员之日', '参加入党宣誓仪式之日', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('预备党员预备期为（ ）。', '1', '低', '', 'A', '一年', '二年', '三年', '四年', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('预备党员需要继续考察和教育的，可以延长预备期，延长时间不能少于（ ）。', '1', '低', '', 'B', '3 个月', '6 个月', '9 个月', '1 年', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('预备党员延长预备期最长不超过（ ）。', '1', '低', '', 'B', '6 个月', '1 年', '1.5 年', '2 年', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('预备党员预备期满，认真履行党员义务、具备党员条件的，应当（ ）。', '1', '低', '', 'B', '延长预备期', '按期转为正式党员', '取消预备党员资格', '重新考察', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('预备党员不履行党员义务、不具备党员条件的，应当（ ）。', '1', '低', '', 'C', '延长预备期', '按期转为正式党员', '取消预备党员资格', '重新入党', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('预备党员转为正式党员、延长预备期或取消预备党员资格，应当经（ ）讨论通过和上级党组织批准。', '1', '低', '', 'A', '支部党员大会', '支部委员会', '党小组会', '上级党委会议', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('入党积极分子培养联系人一般由（ ）担任。', '1', '低', '', 'A', '。正式党员', '预备党员', '入党申请人', '群众', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('对入党积极分子的培养教育方式不包括（ ）。', '1', '低', '', 'C', '听报告', '个人自学', '批评打击', '参加党内活动', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('发展对象政治审查的基本方法不包括（ ）。', '1', '低', '', 'D', '同本人谈话', '查阅有关档案材料', '函调或外调', '随意猜测', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('政治审查的内容中，不包括对发展对象（ ）的审查。', '1', '低', '', 'C', '直系亲属', '主要社会关系', '朋友的朋友', '本人政治历史', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('基层党委或县级党委组织部门应当对发展对象进行不少于（ ）的集中培训。', '1', '低', '', 'B', '24 学时', '32 学时', '40 学时', '48 学时', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('填写入党志愿书，须经（ ）同意，在入党介绍人指导下，由本人按照要求如实填写。', '1', '低', '', 'A', '支部委员会', '上级党委', '党小组', '党员大会', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('入党介绍人一般由（ ）担任。', '1', '低', '', 'A', '培养联系人', '支部书记', '群众代表', '预备党员', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('入党介绍人一般由（ ）指定。', '1', '低', '', 'A', '支部委员会', '上级党委', '党小组', '党员大会', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('预备党员必须面向（ ）进行入党宣誓。', '1', '低', '', 'B', '国旗', '党旗', '团旗', '司旗', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('入党宣誓仪式，一般由（ ）组织。', '1', '低', '', 'A', '基层党委或党支部 （党总支）', '上级党委', '党小组', '党员大会', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党组织对党员的日常教育管理方式不包括（ ）。', '1', '低', '', 'C', '组织生活会', '民主评议党员', '不管不问', '谈心谈话', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党员组织关系介绍信是党员政治身份的证明，介绍信的有效期一般不超过（ ）。', '1', '低', '', 'B', '1 个月', '3 个月', '6 个月', '9 个月', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党员短期外出学习或工作，时间在（ ），一般应开具党员证明信，交所去单位党组织。', '1', '低', '', 'B', '3 个月及以下', '6 个月及以下', '9 个月及以下', '12 个月及以下', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党员要求退党，应当由（ ）向所在党支部提出书面申请。', '1', '低', '', 'A', '本人', '家属', '同事', '领导', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('对停止党籍的党员，符合条件的，可以按照规定程序（ ）。', '1', '低', '', 'A', '恢复党籍', '重新入党', '开除党籍', '劝其退党', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('预备党员从（ ）起交党费。', '1', '低', '', 'A', '支部大会通过其为预备党员之日', '上级党委批准之日', '确定为预备党员之日', '参加入党宣誓仪式之日', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('在职党员每月工资收入 （税后） 在 3000 元以上至 5000 元 （含 5000 元） 者，交纳月工资收入的（ ）党费。', '1', '低', '', 'B', '0.005', '0.01', '0.015', '0.02', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('离退休党员缴纳标准为 5000 元以上的按（ ）交纳党费。', '1', '低', '', 'B', '0.005', '0.01', '0.015', '0.02', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党费计算基数不包括以下项目中的（ ）。', '1', '低', '', 'B', '基本工资', '住房补贴', '奖金', '津贴', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('每名党员月交纳党费数额一般不超过（ ）。', '1', '低', '', 'C', '500 元', '800 元', '1000 元', '1200 元', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党员教育管理是党的建设的（ ）工作。', '1', '低', '', 'A', '基础性经常性', '重要性阶段性', '核心性长期性', '', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('“三会一课” 应当突出政治学习和教育，以（ ）为主要内容。', '1', '低', '', 'A', '党的理论和路线方针政策', '业务知识学习', '文化知识学习', '', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部每年至少召开（ ）次组织生活会。', '1', '低', '', 'A', '1', '2', '3', '4', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党组织应当通过严格组织生活、听取群众意见、检查党员工作等多种方式，监督党员（ ）。', '1', '低', '', 'A', '履行义务、执行党的决定、遵守党的纪律', '学习情况、工作业绩、生活作风', '思想动态、家庭状况、社交圈子', '', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('对党员不按照规定参加党的组织生活、不按期交纳党费、流动到外地工作生活不与党组织主动保持联系的，以及存在其他与党的要求不相符合的行为、情节较轻的，党组织应当采取（ ）方式进行处理。', '1', '低', '', 'A', '谈话提醒、批评教育', '组织处理', '纪律处分', '', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部一般每年开展（ ）次民主评议党员。', '1', '低', '', 'A', '1', '2', '3', '4', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党员每年集中学习培训时间一般不少于（ ）学时。', '1', '低', '', 'C', '16', '24', '32', '48', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('对新入党的党员，应当进行（ ）。', '1', '低', '', 'A', '集中培训', '个别谈话', '党课教育', '实践锻炼', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('加强党的宗旨教育，引导党员践行（ ）的根本宗旨。', '1', '低', '', 'A', '为人民服务', '为社会主义服务', '为共产主义事业奋斗', '为国家繁荣富强努力', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('强化党章党规党纪教育，引导党员牢记（ ），养成纪律自觉。', '1', '低', '', 'C', '入党誓词', '党员义务', '党的纪律', '党的规矩', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('停止党籍（ ）年后确实无法取得联系的，按照自行脱党予以除名。', '1', '低', '', 'B', '1', '2', '3', '4', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党员要求退党，应当由本人向所在党组织提出（ ）申请。', '1', '低', '', 'B', '口头', '书面', '口头或书面', '无需申请', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('受到劝其退党处置的，（ ）年内不得重新入党。', '1', '低', '', 'C', '3', '4', '5', '6', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('受到除名处置的，（ ）年内不得重新入党。', '1', '低', '', 'C', '3', '4', '5', '6', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党员组织关系是指党员对党的基层组织的（ ）关系。', '1', '低', '', 'B', '领导', '隶属', '指导', '监督', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('有固定工作单位并且单位已经建立党组织的党员，一般编入其（ ）党组织。', '1', '低', '', 'B', '居住地', '工作单位', '户籍所在地', '上级主管部门', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('坚持把党的政治建设摆在首位，（）至少召开1次党组织会议专题研究全面从严治党工作。', '1', '低', '', 'C', '每个月', '每季度', '每半年', '每年', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('约谈、诫勉谈话主体至少（）人，谈话记录需经谈话对象核实签字确认，谈话后应第一时间向本单位党风廉政建设和反腐败工作牵头部门备案。', '1', '低', '', 'B', '1人', '2人', '3人', '', '', '', '', '', '', '', '党风廉政建设', '党建廉政', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('《关于新形势下党内政治生活的若干准则》规定，（ ）是加强和规范党内政治生活的重要手段。', '1', '低', '', 'A', '批评和自我批评', '严明党的纪律', '组织生活会', '坚持选人用人导向', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('《中国共产党廉洁自律准则》要求党员领导干部，廉洁修身，（）。', '1', '低', '', 'C', '自觉维护人民根本利益', '自觉保持人民公仆本色', '自觉提升思想道德境界', '自觉带头树立良好家风', '', '', '', '', '', '', '党风廉政建设', '党建廉政', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('根据《中国共产党纪律处分条例》，实施党纪处分，应当按照规定程序经（）讨论决定，不允许任何个人或者少数人擅自决定和批准。', '1', '低', '', 'C', '党代会', '规定程序', '党组织集体', '党员代表', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('根据《中国共产党纪律处分条例》，党员受到警告处分（ ）内、受到严重警告处分（ ）内，不得在党内提升职务和向党外组织推荐担任高于其原任职务的党外职务。', '1', '低', '', 'B', '一年半；半年', '一年；一年半', '半年；一年', '一年；两年', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('根据《中国共产党纪律处分条例》，党员犯罪，因故意犯罪被依法判处刑法规定的主刑（含宣告缓刑）的，应当给予（ ）处分。', '1', '低', '', 'D', '警告', '严重警告', '撤销党内职务或者留党察看处分', '开除党籍', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('根据《中国共产党纪律处分条例》，借用管理和服务对象的钱款、住房、车辆等，影响公正执行公务；通过民间借贷等金融活动获取大额回报，影响公正执行公务的，情节较重的，给予（ ）处分。', '1', '低', '', 'D', '撤销党内职务', '留党察看', '开除党籍', '警告或者严重警告', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('国有企业党委一般由（  ）人组成，最多不超过 11 人。', '1', '低', '', 'A', '5一9', '7一8', '9', '10', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('根据《中国共产党宣传工作条例》，宣传工作的定位作用是什么？', '1', '低', '', 'A', '宣传工作是党的一项极端重要的工作，是坚持党的政治路线、加强党的政治建设的重要方式。', '宣传工作是党的一项一般性工作，主要用于文化传播。', '宣传工作是党的辅助性工作，服务于经济建设。', '宣传工作是党的临时性工作，根据需求灵活调整。', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('2023年全国宣传思想文化工作会议首次提出了（ ）', '1', '低', '', 'B', '文化强国战略', '习近平文化思想', '宣传思想工作新理念', '社会主义文化新方针', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平文化思想强调，宣传思想文化工作要聚焦（ ）', '1', '低', '', 'B', '经济建设中心', '用党的创新理论武装全党、教育人民', '社会稳定大局', '国际文化交流', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('稿件写作中，涉及到计量单位名称时应使用（）。', '1', '低', '', 'A', '汉字', '繁体字', '英文', '都可以', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('以下场景什么时候拍领导最好', '1', '低', '', 'D', '会议刚开场时', '主持人讲话，领导仔细听时', '领导低头读发言提纲时', '领导抬头讲话时', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('提供媒体的稿件内容应尽量避免', '1', '低', '', 'C', '通俗易懂', '数据准确', '专业名词', '案例充分', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('外媒报道本企业内容的生命线是', '1', '低', '', 'B', '数据详实', '品牌露出', '内容全面', '生动形象', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('宣传工作和（）工作，从工作方式方法上看，具有共通性', '1', '低', '', 'C', '项目经理', '项目履约', '市场营销', '企业管理', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('在宣传策划中，领导人员除了亲自指挥，还要（）', '1', '低', '', 'B', '亲自撰稿', '定调把关', '收集素材', '修改稿件', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('公司官方微信刊发内容不包含', '1', '低', '', 'C', '公司主要领导拜会', '工程节点', '分公司领导拜会', '国家级荣誉', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('以下哪个是中央核心媒体', '1', '低', '', 'A', '《人民日报》纸质版', '中国日报', '《朝闻天下》', '求是网', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目在进行新闻宣传时，应如何把握宣传时机？', '1', '低', '', 'B', '随意选择', '结合工程节点或热点事件', '忽视市场趋势', '听公司安排，不主动开展', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('新闻标题应遵循的原则不包括？', '1', '低', '', 'C', '简洁明了', '引人入胜', '冗长复杂', '结合一句话标签', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('拍摄活动合影时，以下哪种构图方式最不推荐？', '1', '低', '', 'C', '所有人物都面向镜头，排列整齐', '将重要人物放在中心位置', '人物排成一行，背景杂乱无章', '利用CI元素增加层次感', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('拍摄活动照片时，以下哪种拍摄角度最不推荐？', '1', '低', '', 'B', '正面平视角度', '高角度俯拍（直接从上往下拍摄人群）', '低角度仰拍', '侧面拍摄捕捉动态', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('下列哪项不属于公司宣传思想工作的基本原则？', '1', '低', '', 'C', '坚持党管宣传，正面导向', '贴近民生大众', '追求高点击率，忽视内容质量', '坚持改革创新', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中国建筑的企业使命是什么？', '1', '低', '', 'B', '成为最具国际竞争力的投资建设集团', '拓展幸福空间', '品质保障，价值创造', '爱国、奋斗、求实、奉献', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目部应于每（）向企业文化部上报新闻线索。', '1', '低', '', 'C', '周一', '周三', '周五', '周日', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('公司企业文化是（）', '1', '低', '', 'C', '十典九章', '先锋文化', '鲁班文化', '盈利文化', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目部所有稿件或素材均以（）名义报送，不允许直接投稿。', '1', '低', '', 'C', '项目部', '项目经理', '分公司', '通讯员', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局报纸平台是（）', '1', '低', '', 'B', '中建建筑报', '建设者报', '一局说', '建筑先锋报', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('各级党委（党组）多长时间至少专题研究一次意识形态工作？', '1', '低', '', 'C', '每月', '每季度', '每半年', '每年', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中国建筑廉洁文化理念是？', '1', '低', '', 'B', '崇德善建 廉洁奉公', '崇德善建 尚廉筑基', '清正廉洁  自律守信', '清正立身  廉洁齐家', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('下列哪个选项是中建一局的企业愿景？', '1', '低', '', 'C', '品质保障  价值创造', '成为最具国际竞争力的投资建设集团', '成为中国建筑高质量发展排头兵', '拓展幸福空间', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中国建筑“一六六”战略路径中“一”指的是？', '1', '低', '', 'A', '进一步提高政治站位', '新时代党的建设总要求', '创建具有全球竞争力的世界一流企业', '习近平文化思想', '', '', '', '', '', '', '企业战略与经营管理', '企业管理', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局五公司鲁班文化被《中国建筑业年鉴》正式定名的时间是？', '1', '低', '', 'A', '1995年', '1994年', '2023年', '2024年', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('新时代鲁班文化内涵中“精进”的核心要求不包括以下哪项？', '1', '低', '', 'D', '敬业', '精益', '专注', '竞争', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('公司各级党组织书记在文化建设中的角色是？', '1', '低', '', 'A', '第一责任人', '直接责任人', '监督人', '执行人', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('对外展示文化时，以下哪种做法不符合要求？', '1', '低', '', 'C', '同时展示先锋与鲁班文化', '仅展示先锋文化', '仅展示鲁班文化', '优先展示鲁班文化', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('若项目 CI 实施过程中需对策划方案进行变动，正确的做法是？', '1', '低', '', 'A', '在策划书后附补充内容', '重新编写策划方案', '无需任何操作', '向任意部门报备', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('公司组织 CI 交流学习以及与其他单位、CI 创优项目的对标、观摩活动的频率是？', '1', '低', '', 'D', '每周一次', '每月一次', '每季度一次', '适时组织', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('负责与中建一局 CI 主管部门工作对接的是？', '1', '低', '', 'A', '党委工作部', '项目管理部', '商务管理部', '科技质量部', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目 CI 执行小组应在项目开工多久内制订《中建一局施工现场 CI 达标创优策划方案（模板）》？', '1', '低', '', 'B', '两周内', '一个月内', '两个月内', '三个月内', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('CI 达标工程的得分标准是？', '1', '低', '', 'B', '90 分以上', '100 分以上', '110 分以上', '117 分以上', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('公司达到 CI 创优标准的项目数量不少于在施项目数的？', '1', '低', '', 'C', '0.1', '0.15', '0.2', '0.25', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('申报 “鲁班奖” 的工程应达到的 CI 标准是？', '1', '低', '', 'D', 'CI 达标工程', 'CI 创优金奖', 'CI 创优银奖', 'CI 示范工程', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目 CI 用品应选用？', '1', '低', '', 'B', '任意制作商', '公司批准并备案的 CI 合格制作商', '当地制作商', '价格最低的制作商', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('各单位应从哪里选择 CI 制作单位？', '1', '低', '', 'B', '公司内部推荐的名录', '中建一局发布的 CI 合格供应商名录', '自行寻找的制作单位', '当地知名制作单位', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('公司将 CI 达标工程的组织、监督及落实纳入对各基层年度哪项考核成绩中？', '1', '低', '', 'B', '绩效考核', '党建工作责任制考核', '业务能力考核', '综合素养考核', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('CI 验收的评分标准满分为？', '1', '低', '', 'D', '100 分', '110 分', '117 分', '120 分', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目发生重大质量安全事故，造成恶劣社会影响的，对 CI 评比有何影响？', '1', '低', '', 'C', '不影响评比', '降低一个评比等级', '取消评比资格', '视情况而定', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目 CI 执行小组应在新项目开工多久内提交《CI 工作交底及维护记录》？', '1', '低', '', 'C', '一个月内', '两个月内', '三个月内', '半年内', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('CI 创优项目实施 CI 项目不少于多少项，得分标准是多少分以上？', '1', '低', '', 'B', '46 项，100 分', '58 项，110 分', '58 项，117 分', '62 项，120 分', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('各二级公司每年需几次申报、调整 CI 创优、示范项目并报局党建工作部？', '1', '低', '', 'B', '1 次', '2 次', '3 次', '4 次', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('门楼式大门门楣的尺寸为（ ）', '1', '低', '', 'B', '10×1.2m', '10×1.5m', '8×1.2m', '8×1.5m', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('门楼式大门的门楣高度是多少？', '1', '低', '', 'B', '1m', '1.5m', '6.5m', '8m', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('以局名义承接的工程，除施工区大门门楣外，其他地方使用标识简称时，统一以什么为主？', '1', '低', '', 'B', '中建一局', '中国建筑一局', '中建集团', '中国建筑', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('办公室制度牌的标准尺寸是？', '1', '低', '', 'A', '40x60cm', '60x80cm', '50x70cm', '30x50cm', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('智慧建造指挥中心属于哪一篇的内容？', '1', '低', '', 'D', 'CI 通用规范篇', 'CI 达标项目篇', 'CI 创优项目篇', 'CI 示范项目篇', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局在施项目中，塔吊配重臂双面安装的中国建筑标识组合尺寸为', '1', '低', '', 'A', '6.5m x 1.4m', '5.5m x 1.2m', '7.5m x 1.6m', '8m x 1.8m', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('标识反白使用时，字母是什么颜色？', '1', '低', '', 'B', '白色', '蓝色', '镂空', '黑色', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建标识桩属于 CI 达标项目篇中哪个部分的内容？', '1', '低', '', 'B', '施工区', '外部形象展示', '现场图牌', '安全文明施工图牌', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建标识桩主要应用于以下哪种项目？', '1', '低', '', 'B', '房屋建筑项目', '基础设施项目', '装饰装修项目', '园林景观项目', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('施工图牌框架采用的材质主要是？', '1', '低', '', 'B', '铝合金', '不锈钢', '铁', '塑料', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('施工电梯主体位置安装的标识是？', '1', '低', '', 'C', '中国建筑一局', '中建一局', '中国建筑', '以上都不对', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('配电箱防护棚顶部双层硬防护间距不得小于？', '1', '低', '', 'B', '20cm', '30cm', '40cm', '50cm', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('双开门电箱的中国建筑中轴式组合应贴在？', '1', '低', '', 'A', '左侧门中间', '右侧门中间', '左侧门左上角', '右侧门左上角', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('安全标志多个同时出现时，警告标志的颜色是？', '1', '低', '', 'B', '红色', '黄色', '蓝色', '绿色', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('安全通道防护棚每层脚手板的厚度为？', '1', '低', '', 'C', '30mm', '40mm', '50mm', '60mm', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('茶水亭应采用燃烧性能为（ ）的材料搭建？', '1', '低', '', 'A', 'A 级或 B1 级', 'A 级或 B2 级', 'B1 级或 B2 级', '以上都不对', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('办公区临建楼体正中间上方设置的是（ ）', '1', '低', '', 'B', '“中国建筑” 标识', '“中国建筑一局” 标识', '“忠诚担当 使命必达 品质为先 时代争锋”', '“中国建筑 拓展幸福空间”', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('《十典九章》相关信息视觉制作中，材质一般不包括以下哪种（ ）', '1', '低', '', 'B', '铝合金镜框悬挂', '木质镜框', 'PVC', '亚克力', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目经理部铭牌的材质一般是（ ）', '1', '低', '', 'B', '普通钢板', '拉丝不锈钢板', '铝合金板', '铜板', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('当办公区域较小时，旗台总长度可为（ ）', '1', '低', '', 'B', '3000mm', '3200mm', '3400mm', '3600mm', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('会议室图牌的材质一般为（ ）', '1', '低', '', 'A', '亚克力或 PVCUV 喷印', '木质', '金属', '塑料', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目受检时，会议室桌旗国旗一般朝向（ ）', '1', '低', '', 'C', '进门', 'LED', '检查方', '受检方', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目经理 / 书记室图牌悬挂顺序从左数第一块图牌应为（ ）', '1', '低', '', 'A', '《中建信条・先锋文化》', '《项目执行经理岗位职责》', '《项目经理岗位职责》', '《中建一局建设工程技术质量红线》', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('会议室图牌的材质一般是（ ）', '1', '低', '', 'B', '普通纸张', '亚克力或 PVC UV 喷印', '木质', '塑料板', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('生活区宿舍门牌编号的组成是（ ）', '1', '低', '', 'A', '楼号 + 数字编号', '层号 + 数字编号', '房间号 + 数字编号', '楼号 + 层号 + 房间号', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('文明宿舍管理制度规定，住宿员工每天要做到（ ）', '1', '低', '', 'B', '扫地拖地', '被、鞋叠放整齐', '擦窗户', '整理书桌', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('生活区灭火器适用于扑救各种火灾，使用时需要注意（ ）', '1', '低', '', 'C', '保持距离', '对准火源根部', '不可倒置使用', '先摇晃均匀', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局手提袋的材质是（ ）', '1', '低', '', 'C', '普通 150g 胶板纸', 'PVC', '230g 白卡纸', '', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局标识单独使用特例不包括以下哪个（ ）', '1', '低', '', 'C', '安全帽', '中建腰带', '施工区大门门楣', '', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局名片的规格是（ ）', '1', '低', '', 'A', '90x55mm', '80x40mm', '12x6cm', '210x297mm', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目书记室、项目副书记室哪个需要悬挂的廉洁标语说明牌是？', '1', '低', '', 'C', '项目书记室', '项目副书记室', '都需要', '都不需要', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('安全马甲左胸前的字样是？', '1', '低', '', 'B', '中国建筑', '中建', '一局', '安全施工', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('创优项目主大门总宽度宜为？', '1', '低', '', 'B', '8m', '10m', '6.5m', '1.5m', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('外侧品牌墙常规情况下画面尺寸（无厢房一侧）为？', '1', '低', '', 'A', '6.75 x 4.5m', '6.75 x 3.5m', '5.27 x 4.5m', '5.27 x 3.5m', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('安全教育体验馆的面积建议不得小于（ ）', '1', '低', '', 'B', '10 平米', '15 平米', '20 平米', '25 平米', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('品牌布 / 专用标语（房建）的形式是？', '1', '低', '', 'B', '蓝底黑字', '蓝底白字', '白底蓝字', '红底白字', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('办公区临建为 “U” 形时，先锋文化 “忠诚担当 使命必达 品质为先 时代争锋” 设置在？', '1', '低', '', 'C', '楼体正中间上方', '两侧，字号大于 “中国建筑一局” 标识字号', '两侧，字号小于 “中国建筑一局” 标识字号', '山墙外侧', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('办公区临建为 “一” 形时，山墙上方摆放的 “中国建筑” 中轴式组合，标识总宽为？', '1', '低', '', 'B', '1m', '2m', '3m', '4m', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('道旗的规格通常为？', '1', '低', '', 'B', '300 x 1200mm', '400 x 1500mm', '500 x 1800mm', '600 x 2000mm', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('安全教育讲评台主背景画面常规尺寸为？', '1', '低', '', 'B', '4 x 3m', '6 x 3m', '8 x 3m', '9 x 3m', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('安全教育体验馆建议不得小于多少平米？', '1', '低', '', 'B', '10', '15', '20', '25', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('办公区栅栏栏杆标识设置顺序正确的是？', '1', '低', '', 'C', '中国建筑标识、中国建筑一局标识、建证标识', '建证标识、中国建筑标识、中国建筑一局标识', '中国建筑标识、建证标识、中国建筑一局标识', '中国建筑一局标识、中国建筑标识、建证标识', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('门楼式大门发光标识的光源颜色是？', '1', '低', '', 'C', '红色', '绿色', '白色', '黄色', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('示范项目塔吊臂设置的是？', '1', '低', '', 'B', '发光字', '灯带', '图形标识', '彩旗', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局各二级公司发生Ⅱ级（橙色预警）及以上新闻危机事件时，第一时间（  ）上报相关事件信息，并配合完成相关处置工作。', '1', '低', '', 'B', '半小时内', '1小时内', '2小时内', '3小时内', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局各二级公司负责处置（ ）及以下的新闻危机事件。', '1', '低', '', 'C', 'I级（红色预警）', 'Ⅱ级（橙色预警）', 'Ⅲ级（黄色预警）', 'Ⅳ级（蓝色预警）', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('以下新闻危机事件的分级属于（ ）：中建集团三级舆情（较大级事件），或省部级等主流媒体（含报刊、电视台、网站、新闻客户端、微信公众号、微博账号、视频网站及应用等）首发负面报道，或认证微博或知名自媒体账号（粉丝量大于50万）参与信息讨论或转发，事件本身及媒体报道均围绕“中建一局”展开，对企业品牌形象产生重大程度的负面影响。', '1', '低', '', 'B', 'I级（红色预警）', 'Ⅱ级（橙色预警）', 'Ⅲ级（黄色预警）', 'Ⅳ级（蓝色预警）', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('若有人员在新闻发布会过程中进行抗议、闹场，要遵循快速处理、（  ）、柔和处置的原则，切忌简单粗暴的工作方式，防止因处理不当引发次生舆情。', '1', '低', '', 'D', '针锋相对', '殴打谩骂', '保安驱逐', '适度包容', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('明确接受采访的目的是答疑解惑、澄清事实、讲明真相。因此，要围绕主题，简明扼要、有主次地做出应答。警惕记者提问设置“陷阱”，尽量不要回答（   ）的问题，不被记者“牵着鼻子走”。', '1', '低', '', 'A', '超出提纲', '委婉拒绝', '肆意报道', '标签化', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('发言人要坦率、诚实、冷静地谈论具体事实，不要过于宽泛地发表看法；用语接地气，切忌官话套话，准确把握网络语境，酌情转变话语体系，以（  ）回应舆论关切。', '1', '低', '', 'D', '绕圈子', '大篇幅阐述', '粗俗语言', '人性化语言', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('新闻发言人应遵守新闻发布纪律，根据本单位的授权、（  ）对外发布信息，其言论代表本单位的立场，不得以个人名义对外发布任何信息。', '1', '低', '', 'C', '随心所欲', '自己的观点', '统一口径', '临时想法', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('采访结束后，要保持与记者沟通，及时提供（  ），以使报道更加准确、客观。掌握新闻刊发时间、形式、版面位置等内容，便于企业精准监测，并对回应效果进行评估。', '1', '低', '', 'B', '小道消息', '经授权的内容数据', '企业秘密', '经营数据', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('记者一般会持拟采访材料先行沟通，采访单位要了解相关内容再做下一步应对；交流过程注意保存对话的聊天记录、录音、录像等材料，为应对报道出现偏颇、争议等极端特殊情况留存证据；需特别注意对企业信息的（  ），避免给企业带来不必要的麻烦。', '1', '低', '', 'A', '保密', '宣传', '讲解', '解读', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('如确定接受记者采访，就采访时间、地点、采访人员、（   ）、采访形式等问题进行沟通对接，并对是否可以拍照/录音/录像、是否需要审稿、采访稿发布形式做具体约定。', '1', '低', '', 'C', '新闻发言人', '项目经理', '采访提纲', '项目书记', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('如果媒体突然陪同客户、员工、合作商、工人等利益相关方来采访，且利益相关方情绪激动，应礼貌地将来者一同请到会议室，为现场“降温”。及时了解事情经过，联系相关负责人尽快赶到协商处理。若无法立刻解决则表明公司立场，争取媒体中立报道。媒体离开后着手准备（   ），发给采访记者，并在相关部门内部统一口径。', '1', '低', '', 'A', '书面回应', '新闻发布', '事件报告', '会议纪要', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('面对记者提出的采访提纲外的问题，若不偏离采访提纲，可谨慎回答；若偏离提纲，在对相关内容不了解或者没有被授权的情况下，可委婉拒绝。如记者提出的问题尖锐、加入假设前提、包含较多负面词汇，切记不可重复记者假设性、负面性问题，以免在后续报道中被（   ）。', '1', '低', '', 'D', '委婉拒绝', '正面宣传', '肆意报道', '标签化', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('开新闻发布会前需确定出席人员，公司新闻发言人、总部相关部门及子企业负责人、指定主持人、（   ）要出席发布会，如遇特殊情况可指定新闻发言人；对新闻发言人要授权到位、支持到位、保护到位。', '1', '低', '', 'C', '宣传主管', '安保人员', '回答问题人员', '会服人员', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('若多家未被邀请参加发布会的媒体“不请自来”，应安排（   ）与其对接，讲明客观原因，不能保证邀请到所有媒体机构，也不能保证每一位记者的提问机会，留下记者的联系方式，表明会后将进行统一沟通，争取其理解和客观报道。', '1', '低', '', 'A', '专人', '保安', '服务员', '司机', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('新闻危机处置形式包括新闻发布会、发表公司声明、 发新闻稿、组织报道、接受记者采访、举行网上新闻发布和（   ）等形式。', '1', '低', '', 'D', '座谈会', '网上硬怼', '朋友圈发布', '线上交流', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('一局及局二级公司新闻发言人为分管宣传和品牌传播的领导，临时新闻发言人为（   ）。', '1', '低', '', 'B', '党委书记', '业务系统分管领导', '党建工作部部长', '舆情管理人员', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('新闻发布会会场的主题调性应与舆情事件性质相符，若到场记者人数较多，可在发布台前设置（   ），以保证发布会的有序进行。同时，尽可能保证发布人与媒体记者通过不同的通道进出会场。', '1', '低', '', 'D', '领导席', '主流媒体席', '自媒体席', '隔离禁入区', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('当新闻发布者因发布（  ）等原因导致怯场、冷场等挑战时，主持人需要及时（  ），可以提醒记者提问的范围，还可以建议将某个问题放到会后作进一步交流。若记者提出与本场新闻发布会（  ），可表示问题不在本次发布会议的议程中，不做（  ）。当媒体提问互动中，个别记者提问过于积极，可婉言协调，避免影响他人提问。可以这样答复：“抱歉，那边的记者朋友也一直在示意提问，能否把提问机会留给他/她？”', '1', '低', '', 'C', '无关的问题/补台圆场/准备不足/具体回应', '无关的问题/准备不足/补台圆场/具体回应', '准备不足/补台圆场/无关的问题/具体回应', '准备不足/补台圆场/具体回应/无关的问题', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('对于安全生产事件的舆情回应口径，应（  ）责任主体范围，尽量不提及企业名称等信息（可用“一小区”或“一工地”等代替）；事件信息要（   ），不隐瞒、不谎报；事件基本情况包括时间、地点、事件发生过程、人员伤亡和财产损失情况、影响范围等；处置情况包括处置的措施、进展情况等；如有人员伤亡，需向家属及社会、公众致歉；事件原因以（   ）为准；安全排查及后续整改措施。答案', '1', '低', '', 'D', '扩大/客观真实/项目部调查结果', '缩小/虚构情况/公司调查结果', '扩大/虚构情况/相关政府部门调查结果', '缩小/客观真实/相关政府部门调查结果', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('新闻发言人除了要掌握必备的知识、能力和谈话技巧外，需确保（    ）、条理清晰，避免发言人成为当事人、舆论引导者成为舆论制造者。', '1', '低', '', 'C', '激情洋溢', '活泼可爱', '心态平和', '心浮急躁', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('发生I级（红色预警）事件时，业务主管部门和（  ）起草应答口径，包括对外回应口径、媒体问询口径、舆论引导口径等；（  ）对应答口径进行合法合规性审核；（  ）联合舆情专家进行润色，并研判口径发布平台、形式；局主要领导及相关业务分管领导审定口径。答案：（    ）', '1', '低', '', 'D', '法律部门/主责单位/品牌管理部', '品牌管理部/主责单位/法律部门', '主责单位/品牌管理部/法律部门', '主责单位/法律部门/品牌管理部', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('对于发生过1次及以上新闻危机事件（Ⅲ级黄色预警及以上）的项目，对事件处置不及时并造成负面影响的，该项目部及项目经理（  ）一律不能参加所在公司、一局及中建集团的各类奖项评比。', '1', '低', '', 'D', '2年内', '3年内', '5年内', '本年度', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('新闻发言人职责是指在一定时间内，就企业某一重大事件、重大活动或重要情况约见媒体记者或举行（  ）、记者见面会，代表企业向媒体发布相关新闻信息，阐述企业的观点立场，并回答记者提问。', '1', '低', '', 'C', '座谈会', '研讨会', '新闻发布会', '采风', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('下面人员中，谁可以是项目的新闻发言人：', '1', '低', '', 'C', '安全部经理', '质量部经理', '项目经理/一肩挑书记', '办公室主任', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('对于不同事件类型，应急策略也有很大的不同。全部有错要（  ）；局部有错要（  ）；误解误传要（  ）；恶意诬陷要（  ）；特殊情况要寻求帮助，积极配合。', '1', '低', '', 'D', '态度为先、马上改正/及时沟通、解疑释惑/查明事实、分清责任/果断处置，诉诸法律', '查明事实、分清责任/态度为先、马上改正/及时沟通、解疑释惑/果断处置，诉诸法律', '及时沟通、解疑释惑/态度为先、马上改正/查明事实、分清责任/果断处置，诉诸法律', '态度为先、马上改正/查明事实、分清责任/及时沟通、解疑释惑/果断处置，诉诸法律', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('新闻发布会总体流程为（    ）、宣布发布会结束。', '1', '低', '', 'C', '宣布新闻发布会议程、发布者发布信息、媒体提问互动', '主持人介绍新闻发布者及新闻发布团队、宣布新闻发布会议程、发布者发布信息', '主持人介绍新闻发布者及新闻发布团队、宣布新闻发布会议程、发布者发布信息、媒体提问互动', '主持人介绍新闻发布者及新闻发布团队、宣布新闻发布会议程、媒体提问互动', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('一般情况下，我方被主管监管部门基于事实进行的通报，(  ）主动回应，重点在于事后向相关单位的整改汇报。若第一时期内我方集中出现安全生产事故，被媒体集中解读，可准备媒体备答口径，重点体现企业整改态度与措施。', '1', '低', '', 'C', '适度', '立即', '无需', '积极', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('辨认真假记者。一些号称自己是XX媒体的记者，其实可能是无任何资质、不隶属于任何单位的假记者，因此需及时核实记者身份。可要求记者提供（  ）、单位名称、姓名等信息，通过网络、短信、电话等途径查询，以辨真伪。', '1', '低', '', 'C', '身份证', '工作证', '记者证', '驾驶证', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('发言人说话要（  ），避免（  ）和（  ），不使用极端形容词或副词，如全部、所有、圆满、完全、肯定、所有、绝对等字眼。避免这样的回应：“XX部门不存在任何问题……”“我们百分之百保证不会再出现此类问题……”', '1', '低', '', 'D', '绝对化表述/留有余地/过度承诺', '过度承诺/留有余地/绝对化表述', '过度承诺/绝对化表述/留有余地', '留有余地/绝对化表述/过度承诺', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('发言人要学会说“不”。时刻牢记自己的职务授权范围，不要让自己成为发布会的（  ）。针对一些敏感或未经授权回答的问题，或者新闻发言人不清楚的问题，不要（  ），可将问题转给（  ），或委婉地将（  ）。可以这样回应：“这个问题我不太清楚，我们的XX部门负责人对这个情况比较了解，请他/她来回答您的问题。”或“这个问题我不太清楚，为了给您一个负责任的、清楚的答复，我愿意详细了解情况后再回答您。”', '1', '低', '', 'C', '中心焦点/掌握情况的负责人/勉强回答/问题规避', '中心焦点/问题规避/勉强回答/掌握情况的负责人', '中心焦点/勉强回答/掌握情况的负责人/问题规避', '中心焦点/勉强回答/问题规避/掌握情况的负责人', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('同时接待多家媒体时，不论媒体级别影响力、记者职位高低都应（  ），不要和记者产生对立情绪，无论媒体的来意如何，保持友善、平和态度', '1', '低', '', 'D', '区别对待', '不理不睬', '厚此薄彼', '一视同仁', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('调查媒体真实性，对接受采访的媒体进行筛选。一般选取权威、影响力较大、与企业持续保持良好合作关系的媒体进行事件采访与舆情回应。若遇电话采访或现场截访，需（  ），详细记录媒体名称、记者姓名、联系方式等，引导记者采访指定的新闻发言人。', '1', '低', '', 'C', '报告项目经理', '拒绝采访', '核实记者身份', '报告公司', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('保修期内建筑外观坠落造成人员伤亡或财产损失，引发媒体客观报道后，企业一般（  ），主要配合做好线下处置工作。若通过业主信、公示栏等形式进行回应，最好将回应范围缩小至（  ），减少负面信息对企业整体形象的损害。如报道将责任直接指向我方且舆论影响较大，企业可考虑通过自有官方渠道或第三方媒体进行回应。如伤亡情况严重引发全网关注，一般由地方政府部门（地方发布、住建、质监等）发布情况说明。答案（  ）：', '1', '低', '', 'D', '主动回应/物业管理公司', '主动回应/子企业', '不做主动性回应/总包单位', '不做主动性回应/物业管理公司', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目部要抓好项目管理人员和分包队伍、（   ）的新闻危机管理教育培训，提高防范新闻危机的应对技能，组织预案演练。', '1', '低', '', 'C', '学校', '工人', '门卫', '厨师', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('根据《中建集团干部职工媒体、网络行为负面清单》要求，不制造、不传播各类谣言特别是（）谣言，不散布小道消息。', '1', '低', '', 'C', '经营类', '文化类', '政治类', '活动类', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('接到媒体采访需求时，正确的处理顺序为（  ）①了解媒体的基本情况；②核实记者的身份职务；③转交宣传部门办理。', '1', '低', '', 'A', '①②③', '②①③', '②③①', '①③②', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('正式采访前，根据采访背景、采访时间和内容、拟发布的平台和形式、报道倾向风格、受访者要求等信息，结合舆论环境以及本单位工作实际，制定（），准备采访应答口径以及提供媒体所需的采访参考材料。', '1', '低', '', 'B', '采访清单', '采访方案', '口径清单', '口径方案', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('对于误解误传要及时沟通，解释疑惑。需及时与利益相关方进行沟通，澄清谣言。备答口径需还原事实、说明事实真相，同时借助第三方（如政府机构、行业协会等），进行正向引导。必要时可以向（）请求支持，及时处置不良信息。', '1', '低', '', 'B', '公安局', '网信部门', '宣传部门', '业务相关部门', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('面对突发事件，项目部应第一时间（  ）向公司报告有关情况；抓好现场的控制，对企业标识、名称等品牌元素进行保护性处理；迅速稳定员工及民工队伍，立即进入应急处置程序；在上级领导尚未到达现场前，由项目部新闻发言人做好现场媒体的友好接洽与沟通；在征得上级单位同意后，及时与当地政府有关部门进行联系，争取帮助。', '1', '低', '', 'A', '30分钟内', '1小时', '2小时', '15分钟', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('以下不属于突发（危机）事件 的是（）：', '1', '低', '', 'D', '某项目所在地区发生地震，导致部分人员伤亡。', '某项目食堂发生爆炸，造成1死3伤。', '某公司多名员工由于不满薪酬制度在政府单位门口静坐示威。', '某公司员工在休假期间见义勇为，登上微博热搜。', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('子企业召开新闻发布会或记者见面会，要提前（）并接受指导；项目部召开新闻发布会或记者见面会，要提前（）并接受指导。', '1', '低', '', 'D', '报请有关部门批准，报请局批准', '报请局批准，报请有关部门批准', '报请有关部门批准，报请本单位主管部门批准', '报请局批准，报请本单位主管部门批准', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('工会会员的入会条件是什么？', '1', '低', '', 'A', '以工资收入为主要生活来源或与用人单位建立劳动关系', '必须是党员', '必须是企业法人', '必须是公务员', '', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('工会会员的权利不包括以下哪一项？', '1', '低', '', 'C', '选举权', '被选举权', '表决权', '任免权', '', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('工会基层组织的任期是多久？', '1', '低', '', 'A', '三年或五年', '一年', '两年', '四年', '', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('工会经费的主要来源是什么？', '1', '低', '', 'A', '会员会费和企业拨缴经费', '政府拨款', '社会捐赠', '企业利润', '', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('工会经费的使用范围不包括以下哪一项？', '1', '低', '', 'D', '职工服务', '工会活动', '工会办公', '企业经营', '', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('工会组织职工开展劳动竞赛的主要目的是什么？', '1', '低', '', 'A', '提高职工劳动技能和工作效率', '增加企业利润', '提升企业形象', '增强职工凝聚力', '', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('工会组织职工开展文体活动的主要目的是什么？', '1', '低', '', 'A', '丰富职工精神文化生活，增强职工凝聚力', '提高职工身体素质', '增加企业利润', '提升企业形象', '', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('工会组织职工参与民主管理、民主监督的主要形式是什么？', '1', '低', '', 'A', '职工代表大会', '工会会员大会', '职工大会', '工会委员会', '', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('工会组织职工参与企业决策、监督的主要途径是什么？', '1', '低', '', 'A', '职工代表大会', '工会会员大会', '职工大会', '工会委员会', '', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('职工代表大会每届任期为多久？', '1', '低', '', 'C', '一年', '两年', '三年至五年', '五年以上', '', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('职工代表在任期内调离本企业或退休时，代表资格如何处理？', '1', '低', '', 'A', '代表资格自行终止', '代表资格保留', '重新选举', '无须处理', '', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('职工代表大会的最低代表人数要求是多少？', '1', '低', '', 'A', '不少于全体职工人数的5%，最少不少于30人', '不少于全体职工人数的10%', '不少于50人', '不少于全体职工人数的1%', '', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('职工代表大会的提案应由谁提出？', '1', '低', '', 'A', '职工代表', '企业领导', '工会主席', '外部专家', '', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('职工代表大会的会议制度要求每年召开几次？', '1', '低', '', 'A', '每年一次', '每半年一次', '每季度一次', '每月一次', '', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团支部是团的（ ）组织', '1', '低', '', 'B', '最高', '基础', '临时', '特殊', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团支部的调整和撤销，最终决定权在（）。', '1', '低', '', 'D', '同级党组织', '团员大会', '团支部书记', '上级团委', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团支部的基本任务不包括（）。', '1', '低', '', 'B', '组织团员学习党的理论', '审批预备党员', '开展主题团日活动', '推荐优秀团员入党', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团支部接收团员组织关系转接后，需在（ ）内完善“智慧团建”信息', '1', '低', '', 'B', '1周', '1个月', '2个月', '3个月', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团支部开展主题团日的频率应为（）。', '1', '低', '', 'C', '每半年至少一次', '每年至少一次', '每月至少一次', '每季度至少一次', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团支部书记的任期一般为（）。', '1', '低', '', 'B', '1年', '2年或3年', '5年', '无固定任期', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团员加入共产党后，若年满28周岁且未担任团内职务，应如何处理？', '1', '低', '', 'D', '继续保留团籍', '自动退团', '需申请保留团籍', '不再保留团籍', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团的基层组织团员人数超过100人时，可以建立（）。', '1', '低', '', 'C', '支部', '总支部', '基层委员会', '临时小组', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团的基层组织团员人数超过30人时，可以建立（）。', '1', '低', '', 'B', '支部', '总支部', '基层委员会', '临时小组', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团员的纪律处分中，最高级别的处分是（）。', '1', '低', '', 'D', '警告', '严重警告', '留团察看', '开除团籍', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团章规定，团员没有正当理由，连续（  ）不交纳团费、不过团的组织生活，均被认为是自行脱团？', '1', '低', '', 'B', '3个月', '6个月', '10个月', '12个月', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团的基层组织不包括（  ）？', '1', '低', '', 'A', '地方委员会', '基层委员会', '总支部委员会', '支部委员会', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团歌为（  ）。', '1', '低', '', 'A', '《光荣啊，中国共青团》', '《五月的花海》', '《共青团员之歌》', '《义勇军进行曲》', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团支部成立申请需在（ ）个月内获得批复。', '1', '低', '', 'D', '10', '15天', '28天', '1个月', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团支部调整或撤销的决定权属于（ ）。', '1', '低', '', 'D', '同级党组织', '团员大会', '团支部书记', '上级团委', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团支部的任期一般为（ ）年。', '1', '低', '', 'C', '1-2年', '1-3年', '2-3年', '3-5年', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团支部的“三会两制一课”不包括（）。', '1', '低', '', 'D', '支部大会', '团小组会', '团员教育评议制', '民主生活会', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团支部（ ）至少召开1次组织生活会，组织生活会一般以团支部团员大会、团支部委员会会议或者团小组会形式召开。', '1', '低', '', 'D', '每季度', '每半年', '每月', '每年', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('五四红旗团委（团支部）的评选周期是多久一次？（）', '1', '低', '', 'A', '每年一次', '每两年一次', '每三年一次', '每五年一次', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('青年文明号活动的评选周期是多久一次？（）', '1', '低', '', 'B', '每年一次', '每两年一次', '每三年一次', '每五年一次', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中国青年五四奖章的评选是否面向基层一线？', '1', '低', '', 'A', '是', '否', '', '', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('“13511”青年精神素养提升工作体系中第一个1指的是', '1', '低', '', 'B', '1个原则', '1个目标', '1个要求', '1个任务', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('《关于新时代新征程加强和改进团员队伍建设工作的意见》要求将什么作为基层团组织规范化建设的重要内容？', '1', '低', '', 'B', '理论学习', '志愿服务', '创业创新', '文体活动', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('“三会两制一课”中的“三会”不包括以下哪项？', '1', '低', '', 'D', '支部大会', '支部委员会', '团小组会', '团员代表大会', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('落实“三会两制一课”是共青团保持和增强什么特性的必然要求？', '1', '低', '', 'A', '政治性、先进性、群众性', '政治性、先进性、纯洁性', '政治性、先进性、创新性', '政治性、先进性、服务性', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('“党建带团建”工作的主要内容不包括以下哪项？', '1', '低', '', 'A', '带企业文化建设', '带思想建设', '带组织建设', '带团干部队伍建设', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('“党建带团建”工作的目标任务不包括以下哪项？', '1', '低', '', 'D', '建立完善“党建带团建”工作机制', '提高团组织的服务能力、凝聚能力、学习能力、合作能力、战斗能力', '保持和增强团组织的政治性、先进性、群众性', '提高企业市场竞争力', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部书记每年至少为青年团员上（）次党课。', '1', '低', '', 'A', '一次', '两次', '三次', '四次', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('把团的建设纳入（）总体规划。', '1', '低', '', 'C', '公司发展战略规划', '团组织自身建设规划', '同级党的建设总体规划', '上级党的建设总体规划', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('各级党组织每年至少召开（）次专门会议，听取团青工作汇报。', '1', '低', '', 'D', '四次', '三次', '两次', '一次', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('公司把党建带团建工作情况作为（）考核内容。', '1', '低', '', 'C', '公司绩效考核内容', '青年工作考核内容', '党建工作责任制考核内容', '', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局五公司“青年马克思主义者培养工程”实施方案培养内容中，理论学习的主要方式不包括（）。', '1', '低', '', 'D', '线上学习', '线下授课', '课题研究', '公益行动', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('保留团籍的共产党员从何时起可不交纳团费？', '1', '低', '', 'B', '入党之日', '取得预备党员资格起', '转为正式党员后', '党组织关系转出后', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('流动团员团费交纳地点为（）。', '1', '低', '', 'B', '流出地团组织', '流入地团组织', '户籍所在地团组织', '工作单位团组织', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团干部教育培训要求新任职团干部在多长时间内完成培训？', '1', '低', '', 'B', '3个月', '6个月', '9个月', '12个月', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团组织对连续6个月不交团费的团员应如何处理？', '1', '低', '', 'D', '警告处分', '取消评优', '补交即可', '自行脱团', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('“两个一以贯之”的原则中，不包括以下哪2项？', '多选', '2', '中', '', 'CD', '坚持党对国有企业的领导', '建立现代企业制度', '坚持市场化改革', '把党的领导融入公司治理各环节', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('“两个确立”指的是什么？', '多选', '2', '中', '', 'BC', '确立中国特色社会主义理论体系的指导地位', '确立习近平新时代中国特色社会主义思想的指导地位', '确立习近平同志党中央的核心、全党的核心地位', '确立党中央的集中统一领导', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党风廉政建设“两个责任”指的是？', '多选', '2', '中', '', 'AB', '党委的主体责任', '纪委的监督责任', '经理层的执行责任', '员工的参与责任', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建集团“六个塑强”包括哪些内容？', '多选', '2', '中', '', 'ABC', '塑强房建首位优势', '塑强基建支柱优势', '塑强地产卓越优势', '塑强科技创新优势', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局五公司“鲁班文化”的核心理念包括哪些？', '多选', '2', '中', '', 'ABD', '担当', '精进', '创新', '超越', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局五公司的企业文化建设目标包括哪些？', '多选', '2', '中', '', 'ABCDE', '培育共同价值观', '增强团队凝聚力', '提升企业形象', '促进企业发展', '提高员工满意度', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党风廉政建设“两个责任”中，党委的主体责任要求各级党委怎么做？', '多选', '2', '中', '', 'ABC', '牢固树立不抓党风廉政建设就是严重失职的意识', '解决好不想抓、不会抓、不敢抓的问题', '切实担负起党风廉政建设的主体责任', '履行好监督责任', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('“一岗双责”中的“双责”指的是？', '多选', '2', '中', '', 'AB', '对所在岗位应当承担的具体业务工作负责', '对所在岗位应当承担的党风廉政建设责任制负责', '对所在单位的行政管理负责', '对所在单位的文化建设负责', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('“两个一以贯之”强调了什么？', '多选', '2', '中', '', 'ABCD', '坚持党对国有企业的领导', '建立现代企业制度', '把党的领导融入公司治理各环节', '把企业党组织内嵌到公司治理结构之中', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('以下哪些属于全国组织工作会议提出的“十三个坚持”内容？', '多选', '2', '中', '', 'ABCD', '坚持和加强党的全面领导', '坚持以党的自我革命引领社会革命', '坚持以党的政治建设统领党的建设各项工作', '坚持制度治党、依规治党', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建集团“一个提高”指提高政治站位，其原因是什么？', '多选', '2', '中', '', 'ABC', '政治站位是国有企业做好一切工作的首要前提', '国有企业的最大优势是政治优势', '集团作为国有重要骨干企业必须旗帜鲜明讲政治', '提高政治站位有助于提升企业经济效益', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建集团“六个塑强”包括以下哪些优势的塑强？', '多选', '2', '中', '', 'ABCD', '房建首位优势', '基建支柱优势', '地产卓越优势', '塑强设计领先优势', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局先锋文化的特点包含哪些？', '多选', '2', '中', '', 'AB', '以“忠诚担当、使命必达”为精神内核', '以“品质为先、时代争锋”为行动标准', '以“开拓创新、追求卓越”为发展理念', '以“和谐发展、共创未来”为长远目标', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局“155大党建工作格局”中，第一个“5”即两级党组织要全面履行的“五项职能”包括哪些？', '多选', '2', '中', '', 'ABCD', '抓战略、掌全局', '抓班子、带队伍', '抓文化、塑品牌', '抓自身、创价值', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局项目党支部“五个价值创造点”包括以下哪些？', '多选', '2', '中', '', 'ABCD', '组织建设', '目标完成', '制度执行', '廉洁从业', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局五公司“鲁班文化”中的“担当”体现在哪些方面？', '多选', '2', '中', '', 'ABD', '政治担当', '责任担当', '家庭担当', '业务引领担当', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建集团“一创五强”战略目标中“五强”指的是哪些方面强？', '多选', '2', '中', '', 'ABCD', '价值创造力强', '国际竞争力强', '行业引领力强', '品牌影响力强', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局“1135”战略体系中“3个关键路径”包括哪些？', '多选', '2', '中', '', 'ABC', '推进国内国外两个市场“1 + 3”产业发展战略和“一化三线”市场营销战略', '推进项目管理三大建设和价值创造能力建设', '推进治理体系建设和公司化建设', '推进企业文化建设', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局“五力并举”战略路径包括提高哪些方面的能力？', '多选', '2', '中', '', 'ABCD', '提高党建引领力', '提高产业竞争力', '提高经营创效力', '提高企业治理力', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局五公司“11336”战略思想中的“三个驱动”指的是哪些驱动？', '多选', '2', '中', '', 'ABC', '转型驱动', '创新驱动', '文化驱动', '市场驱动', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('坚持和加强党的全面领导，要（ ）。', '多选', '2', '中', '', 'ABCD', 'A. 深刻领悟“两个确立”的决定性意义', 'B. 增强“四个意识”', 'C. 坚定“四个自信”', 'D. 做到“两个维护”', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记指出，党的自我革命是（ ）。', '多选', '2', '中', '', 'ABCD', 'A. “跳出治乱兴衰历史周期率的第二个答案”', 'B. 以伟大自我革命引领伟大社会革命', 'C. 以伟大社会革命促进伟大自我革命', 'D. 全面推进党的自我净化、自我完善、自我革新、自我提高', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('加强党的政治建设，要提高各级党组织和党员干部的（ ）。', '多选', '2', '中', '', 'ABCD', 'A. 政治判断力', 'B. 政治领悟力', 'C. 政治执行力', 'D. 政治领导力', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党内集中教育包括（ ）等。', '多选', '2', '中', '', 'ABCD', 'A. 党的群众路线教育实践活动', 'B. “三严三实”专题教育', 'C. “两学一做”学习教育', 'D. “不忘初心、牢记使命”主题教育', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记提出新时代党的组织路线，强调（ ）。', '多选', '2', '中', '', 'ABC', 'A. 党的力量来自组织', 'B. 以组织体系建设为重点', 'C. 增强党组织政治功能和组织功能', 'D. 坚持人民至上', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('关于党的组织建设，下列说法正确的是（ ）。', '多选', '2', '中', '', 'ABCD', 'A. 组织建设是党的建设的重要基础', 'B. 是党的建设总体布局的重要物质依托', 'C. 着力培养忠诚干净担当的高素质干部', 'D. 着力集聚爱国奉献的各方面优秀人才', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('一体推进不敢腐、不能腐、不想腐，要（ ）。', '多选', '2', '中', '', 'ABCD', 'A. 加强对权力运行的制约和监督', 'B. 扎紧制度的笼子', 'C. 强化理想信念教育', 'D. 提高党性觉悟', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党章规定，党员享有下列权利：（ ）。', '多选', '2', '中', '', 'ABCD ', 'A. 参加党的有关会议，阅读党的有关文件，接受党的教育和培训', 'B. 在党的会议上和党报党刊上，参加关于党的政策问题的讨论', 'C. 对党的工作提出建议和倡议', 'D. 行使表决权、选举权，有被选举权', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党的基层组织，根据工作需要和党员人数，经上级党组织批准，分别设立（ ）。', '多选', '2', '中', '', 'ABC ', 'A. 党的基层委员会', 'B. 总支部委员会', 'C. 支部委员会', 'D. 党小组', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党的纪律主要包括（ ）、工作纪律、生活纪律。', '多选', '2', '中', '', 'ABCD ', 'A. 政治纪律', 'B. 组织纪律', 'C. 廉洁纪律', 'D. 群众纪律', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党章规定，党的各级领导干部必须具备的基本条件包括（ ）。', '多选', '2', '中', '', 'ABCD ', 'A. 具有履行职责所需要的马克思列宁主义、毛泽东思想、邓小平理论、“三个代表”重要思想、科学发展观、习近平新时代中国特色社会主义思想的水平', 'B. 坚决执行党的基本路线和各项方针、政策，立志改革开放，献身现代化事业', 'C. 坚持实事求是，认真调查研究，能够把党的方针、政策同本地区、本部门的实际相结合，卓有成效地开展工作', 'D. 有强烈的革命事业心和政治责任感，有实践经验，有胜任领导工作的组织能力、文化水平和专业知识', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党的基层组织要对党员进行（ ），提高党员素质，坚定理想信念，增强党性。 ', '多选', '2', '中', '', 'ABCD ', 'A. 教育', 'B. 管理', 'C. 监督', 'D. 服务', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('《中国共产党党徽党旗条例》规定，下列哪些情形应当使用党徽（ ）。', '多选', '2', '中', '', 'ABCD', 'A. 召开党的全国代表大会、代表会议', 'B. 党的中央和地方委员会及其工作部门、党的中央和地方委员会在特定地域派出的代表机关及其工作部门、党的纪律检查机关、党组的印章（印模）中间', 'C. 党内重要文件、重大会议文件的封面', 'D. 党内组织证件和党员徽章', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('《中国共产党党徽党旗条例》规定，下列关于党旗使用的说法正确的有（ ）。   ', '多选', '2', '中', '', 'ABCD ', 'A. 举行重大庆祝、纪念活动应当使用党旗', 'B. 开展党的对外交往活动可以使用党旗', 'C. 举行新党员入党宣誓仪式，组织党员重温入党誓词应当使用党旗', 'D. 党内举行重大表彰奖励活动可以使用党旗', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目党支部的基本任务包括（ ）。', '多选', '2', '中', '', 'ABCD', 'A. 宣传和贯彻落实党的理论和路线方针政策', 'B. 组织党员认真学习党的基本知识', 'C. 对党员进行教育、管理、监督和服务', 'D. 做好思想政治工作和意识形态工作', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目党支部“三会一课”中的“一课”，其内容可以包括（ ）。', '多选', '2', '中', '', 'ABC', 'A. 党的基本理论', 'B. 党的优良传统', 'C. 党性党风党纪', 'D. 项目业务知识', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目党支部发展党员的主要程序有（ ）。   ', '多选', '2', '中', '', 'ABCD', 'A. 递交入党申请书', 'B. 确定为入党积极分子', 'C. 确定为发展对象', 'D. 接收为预备党员', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目党支部主题党日活动可以采取的形式有（ ）。 ', '多选', '2', '中', '', 'ABCD', 'A. 参观红色教育基地', 'B. 开展技能竞赛', 'C. 进行志愿服务', 'D. 组织党员座谈会', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('以下属于中国共产党在改革开放时期形成的理论成果的有（ ）。', '多选', '2', '中', '', 'ABCD', 'A. 邓小平理论', 'B. “三个代表” 重要思想', 'C. 科学发展观', 'D. 习近平新时代中国特色社会主义思想', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党的十八大以来，以习近平同志为核心的党中央提出的新发展理念包括（ ）。', '多选', '2', '中', '', 'ABCD', 'A. 创新', 'B. 协调', 'C. 绿色', 'D. 开放、共享', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('严肃党的组织生活，需要认真召开哪些会议，落实哪些制度（ ）。', '多选', '2', '中', '', 'ABCD', '民主生活会', '组织生活会', '谈心谈话、民主评议党员', '主题党日', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('坚持用党的创新理论武装党员干部职工，突出的内容包括（ ）。', '多选', '2', '中', '', 'AB', '政治教育', '党性教育', '道德教育', '法治教育', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('落实全面从严治党主体责任，需要坚决反对的 “四风” 包括（ ）。', '多选', '2', '中', '', 'ABCD', '形式主义', '官僚主义', '享乐主义', '奢靡之风', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('国有企业党员发展工作，应注重在哪些群体中发展党员（ ）。', '多选', '2', '中', '', 'ABC', '生产经营一线', '青年职工', '高知识群体', '管理层', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('国有企业党组织要强化对党员的日常管理，包括（ ）。', '多选', '2', '中', '', 'ABCD', '及时转接党员组织关系', '督促党员按期足额交纳党费', '严格执行党的纪律，对违犯党的纪律的党员及时进行教育或者处理', '做好关心关爱党员工作', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('国有企业党组织要积极适应新形势新任务新要求，不断加强自身建设，提高（ ）。', '多选', '2', '中', '', 'ABC', '凝聚力', '战斗力', '创造力', '领导力', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('国有企业党组织要教育党员努力掌握并自觉运用马克思主义及其中国化最新成果武装头脑、指导实践、推动工作，其中马克思主义中国化最新成果包括（ ）。', '多选', '2', '中', '', 'ABCD', '习近平新时代中国特色社会主义思想', '邓小平理论', '“三个代表”重要思想', '科学发展观', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('基层党组织换届选举前，需对（ ）进行全面审查。', '多选', '2', '中', '', 'ABC', '党员人数', '候选人资格', '选举程序', '财务状况', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('基层党组织的选举方式有（ ）。', '多选', '2', '中', '', 'ABCD', '直接选举', '间接选举', '等额选举', '差额选举', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('基层党组织选举中，确定候选人初步人选后，需进行（ ）。', '多选', '2', '中', '', 'ABC', '组织考察', '征求意见', '公示', '背景调查', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('基层党组织选举时，有效选票应符合（ ）条件。', '多选', '2', '中', '', 'ABD', '填写规范', '所选人数不超过应选人数', '有投票人签名', '在规定时间内投入票箱', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('基层党组织书记在选举工作中，需组织开展（ ）工作。', '多选', '2', '中', '', 'ABCD', '党员动员', '选举培训', '场地布置', '经费预算', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('基层党组织选举时，出现（ ）情况，选举无效。', '多选', '2', '中', '', 'ABCD', '选举过程中发现有舞弊行为', '参加选举人数未达到规定人数', '选票印制不符合要求', '计票错误', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('基层党组织书记候选人推荐方式有（ ）。', '多选', '2', '中', '', 'ABC', '党员推荐', '群众推荐', '党组织推荐', '个人自荐', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('正式党员不足 3 人的单位，应当按照（ ）的原则，成立联合党支部。', '多选', '2', '中', '', 'ABCD', '地域相邻', '行业相近', '规模适当', '便于管理', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部的基本任务包括（ ）。', '多选', '2', '中', '', 'ABCD', '宣传和贯彻落实党的理论和路线方针政策', '组织党员认真学习马克思列宁主义、毛泽东思想、邓小平理论、“三个代表”重要思想、科学发展观、习近平新时代中国特色社会主义思想', '对党员进行教育、管理、监督和服务', '密切联系群众，向群众宣传党的政策', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部工作必须遵循的原则有（ ）。', '多选', '2', '中', '', 'ABCD', '坚持以马克思列宁主义、毛泽东思想、邓小平理论、“三个代表”重要思想、科学发展观、习近平新时代中国特色社会主义思想为指导', '坚持把党的政治建设摆在首位', '坚持践行党的宗旨和群众路线', '坚持民主集中制', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部党员大会的职权包括（ ）。', '多选', '2', '中', '', 'ABCD', '听取和审查党支部委员会的工作报告', '按照规定开展党支部选举工作', '讨论决定对党员的表彰表扬、组织处置和纪律处分', '决定其他重要事项', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部委员会会议的议题一般由（ ）提出。', '多选', '2', '中', '', 'ABC', '党支部书记', '党支部副书记', '党支部委员', '上级党组织', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部开展主题党日，要以（ ）为主要内容。', '多选', '2', '中', '', 'ABCD', '“三会一课”', '组织生活会', '民主评议党员', '志愿服务', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部书记应当具备的基本条件有（ ）。', '多选', '2', '中', '', 'ABCD', '良好政治素质', '热爱党的工作', '具有一定的政策理论水平、组织协调能力和群众工作本领', '敢于担当、乐于奉献', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部的组织生活制度包括（ ）。', '多选', '2', '中', '', 'ABCD', '“三会一课”', '主题党日', '组织生活会', '民主评议党员', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('“三会一课” 中的 “三会” 指的是（ ）。', '多选', '2', '中', '', 'ABC', '党支部党员大会', '党支部委员会会议', '党小组会', '党员代表大会', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部应当经常开展谈心谈话，（ ）之间、（ ）之间、（ ）之间，每年谈心谈话一般不少于 1 次。', '多选', '2', '中', '', 'ABC', '党支部委员之间', '党支部委员和党员', '党员和党员', '党员和群众', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部应当组织党员按期参加党员大会、党小组会和上党课，定期召开党支部委员会会议。“三会一课” 应当突出（ ），以（ ）为主要内容，结合党员思想和工作实际，确定主题和具体方式，做到形式多样、氛围庄重。', '多选', '2', '中', '', 'AB', '政治学习和教育', '党性锻炼', '业务学习', '技能培训', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部应当按照规定，向（ ）通报党的工作情况，公开党内有关事务。', '多选', '2', '中', '', 'AB', '党员', '群众', '上级党组织', '相关单位', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部委员会设书记和组织委员、宣传委员、纪检委员等，必要时可以设（ ）。', '多选', '2', '中', '', 'ABCD', '副书记', '群工委员', '统战委员', '青年委员', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部书记主持党支部全面工作，督促党支部其他委员履行职责、发挥作用，抓好党支部委员会自身建设，向（ ）报告工作。', '多选', '2', '中', '', 'ABC', '党支部委员会', '党员大会', '上级党组织', '所在单位或部门领导', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部应当注重分析党员思想状况和心理状态，党组织负责人应当经常（ ），有针对性地做好思想政治工作。', '多选', '2', '中', '', 'ACD', '同党员谈心谈话', '组织党员心理健康培训', '了解党员诉求', '解决党员实际困难', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部应当教育党员和群众自觉抵制不良倾向，坚决同各种（ ）作斗争。', '多选', '2', '中', '', 'ABCD', '违纪违法行为', '消极腐败现象', '错误思潮', '歪风邪气', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部应当（ ），对入党积极分子进行教育培养，帮助他们端正入党动机、确立为共产主义事业奋斗终身的信念。', '多选', '2', '中', '', 'ABCD', '采取吸收入党积极分子听党课', '参加党内有关活动', '分配一定的社会工作', '集中培训', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部设置形式包括（ ）', '多选', '2', '中', '', 'ABC', '单独成立党支部', '联合党支部', '临时党支部', '流动党支部', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('凡是有正式党员 3 人以上的单位，成立党支部的方式有（ ）', '多选', '2', '中', '', 'ABC', '正式党员超过 3 人且相对固定的单位应单独成立党支部', '正式党员不足 3 人的单位，与其他单位成立联合党支部', '为期 6 个月以上的工程、工作项目等，符合条件的，应单独成立党支部', '不管何种情况，都必须单独成立党支部', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('联合党支部的相关规定正确的有（ ）', '多选', '2', '中', '', 'ABC', '覆盖单位一般不超过 5 个', '对于同一个项目中由多家单位组成的联合党支部，原则上由实际管理项目的单位或股份占比较大的单位牵头', '对于多个单位组成的联合党支部，原则上由支部书记所在单位牵头', '联合党支部党员人数不受限制', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('临时党支部的特点有（ ）', '多选', '2', '中', '', 'ABCD', '主要组织党员开展政治学习等工作', '一般不发展党员、处分处置党员', '临时党支部书记、副书记和委员由批准其成立的党委指定', '临时组建的机构撤销后，临时党支部自然撤销', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部名称规范正确的有（ ）', '多选', '2', '中', '', 'ABC', '应与单位名称相一致', '规范全称一般为中国共产党 XX（此处为单位的规范全称）支部委员会（或支部）', '日常工作中的简称可为 XX（单位的规范简称）党支部', '可以使用新奇名词代替单位名称命名党支部', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部设置程序包括（ ）', '多选', '2', '中', '', 'ABCD', '基层单位提出申请，上级党委召开会议研究决定并批复', '上级党委审批同意后，基层单位召开党员大会选举产生党支部委员会', '根据工作需要，公司党委可直接作出在基层单位成立党支部的决定', '党支部应按规范程序及时成立，一般应在项目成立文件印发之内 1 个月', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部委员会建设内容包括（ ）', '多选', '2', '中', '', 'ABCD', '党支部委员会的选举产生及备案', '党支部书记、副书记的任职条件及选举', '党支部委员的职数、设置及补选', '党小组的划分', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('有正式党员 7 人以上的党支部，设立党支部委员会，委员会成员包括（ ）', '多选', '2', '中', '', 'ABCD', '书记', '组织委员、宣传委员、纪检委员', '党员人数较多的特定项目党支部可设 1 名副书记', '根据实际情况，可另设青年委员、群众委员等', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部书记的任职条件有（ ）', '多选', '2', '中', '', 'ABC', '一般由符合条件的本单位行政第一负责人担任', '须由具有 1 年以上党龄的优秀党员担任', '可以由本单位其他班子成员担任', '必须是单位的业务骨干', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部书记、副书记的选举方式有（ ）', '多选', '2', '中', '', 'ABC', '一般由党支部委员会会议选举产生', '不设委员会的党支部书记、副书记由党支部党员大会选举产生', '公司党委可以指派党支部书记或者副书记', '由上级党委直接任命', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部委员出现空缺时，应（ ）', '多选', '2', '中', '', 'AC', '及时进行补选', '无需处理，等待下次换届', '报公司党委备案', '由党支部书记指定人员补充', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部在划分党小组时应遵循的原则有（ ）', '多选', '2', '中', '', 'ABCD', '根据党员数量和工作需要科学设置', '党员人数在 20 人以上的党支部，一般应当划分若干党小组', '党员人数不足 20 人的，可以根据工作需要划分党小组', '每个党小组不少于 3 名党员，其中至少有 1 名为正式党员', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部委员会换届选举相关正确的有（ ）', '多选', '2', '中', '', 'ABCD', '每届任期一般为 3 年，任期届满按期换届选举', '如需延期或提前换届选举，应报上级党委批准，延长或提前期限一般不超过 1 年', '党支部书记、副书记、委员出现空缺，一般应当召开党员大会及时补选', '换届选举时，有选举权的到会党员数超过应到会有选举权党员数的五分之四方可开会', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部委员会在换届选举前需要做的工作有（ ）', '多选', '2', '中', '', 'ABCD', '召开支部委员会会议，研究召开党员大会进行换届选举相关事宜', '制定工作计划，确定召开党员大会的时间、指导思想等', '确定下届支部委员会委员候选人', '候选人由上届委员会根据多数党员的意见确定，并及时以书面形式报上级党委审批', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部调整和撤销的情况有（ ）', '多选', '2', '中', '', 'ABC', '因党员人数或者所在单位、区域等发生变化，不再符合设立条件', '项目已竣工并完成结算，或已印发项目解体文件', '上级党委认为有必要调整或撤销', '党支部自行决定', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部书记的主要职责有（ ）', '多选', '2', '中', '', 'ABCD', '主持党支部全面工作', '督促党支部其他委员履行职责、发挥作用', '抓好党支部委员会自身建设', '向党支部委员会、党员大会和上级党组织报告工作', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('组织委员的主要职责包括（ ）', '多选', '2', '中', '', 'ABCD', '安排组织生活会和民主评议党员', '督促党支部其他委员履行职责、发挥作用', '抓好党支部委员会自身建设', '向党支部委员会、党员大会和上级党组织报告工作', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('“三会一课” 包括（ ）', '多选', '2', '中', '', 'ABCD', '党员大会', '党支部委员会会议', '党小组会', '党课', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('根据《中国共产党发展党员工作细则》和文档内容，入党申请人可向以下哪些党组织提出入党申请？（ ）', '多选', '2', '中', '', 'ACD', '工作所在单位党组织', '居住地党组织', '流动党员可向单位所在地党组织或单位主管部门党组织、流动党员党组织', '学习所在学校党组织', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('在确定入党积极分子过程中，可采取以下哪些方式产生人选？（ ）', '多选', '2', '中', '', 'AB', '党员推荐', '群团组织推优', '党组织指定', '个人自荐', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('对入党积极分子进行培养教育考察，主要考察哪些方面？（ ）', '多选', '2', '中', '', 'ABC', '政治觉悟、道德品质', '入党动机、工作表现', '学习情况、群众基础', '家庭背景、经济状况', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO single_choice_questions (question_stem, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('入党积极分子经过多长时间培养教育和考察，基本具备党员条件的，可列为发展对象？（ ）', '2', '中', '', 'B', '6 个月以上', '1 年以上', '18 个月以上', '2 年以上', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('列为发展对象，需经过以下哪些流程？（ ）', '多选', '2', '中', '', 'ABC', '支部委员会讨论同意', '经总部党总支、各分公司 / 事业部党委（党总支）研究同意', '报上一级党委备案', '党员大会直接表决', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('支部委员会对发展对象进行审查时，主要审查哪些内容？（ ）', '多选', '2', '中', '', 'ABC', '政治素质、工作表现', '入党材料、遵纪守法情况', '直系亲属和主要社会关系', '兴趣爱好、个人特长', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('分公司 / 事业部党委（党总支）对发展对象进行预审，主要审查哪些方面？（ ）', '多选', '2', '中', '', 'ABC', '培养教育情况', '基本条件、入党手续', '思想汇报、群众意见', '生活作风、消费习惯', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('接收预备党员时，需经过以下哪些程序？（ ）', '多选', '2', '中', '', 'ABC', '经党员大会讨论', '采取无记名投票方式表决', '报公司党委（分公司党委）审批', '上级党委直接任命', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('预备党员预备期满，支部讨论其能否转为正式党员，结果可能有以下哪些？（ ）', '多选', '2', '中', '', 'ABC', '按期转为正式党员', '延长一次预备期', '取消预备党员资格', '继续考察但不延长预备期', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('延长预备党员预备期，延长时间可为以下哪些？（ ）', '多选', '2', '中', '', 'BCD', '3 个月', '6 个月', '9 个月', '12 个月', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('预备党员转为正式党员、延长预备期或取消预备党员资格，需经过以下哪些程序？（ ）', '多选', '2', '中', '', 'AB', '支部大会讨论通过', '上级党组织批准', '党员代表大会表决', '无需任何程序，支部自行决定', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('在发展党员过程中，党支部应做好以下哪些工作？（ ）', '多选', '2', '中', '', 'ABCD', '对入党申请人进行初步审查', '对入党积极分子进行培养教育考察', '对发展对象进行严格审查', '对预备党员进行教育、管理、监督和考察', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('发展党员工作应遵循以下哪些原则？（ ）', '多选', '2', '中', '', 'ABCD', '控制总量', '优化结构', '提高质量', '发挥作用', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党组织在发展党员过程中，要注重考察申请人的入党动机，以下哪些属于正确的入党动机？（ ）', '多选', '2', '中', '', 'AB', '为了全心全意为人民服务', '为了实现共产主义理想', '为了谋取个人利益', '为了获得政治资本', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('发展党员过程中，对入党积极分子的培养联系人应具备以下哪些条件？（ ）', '多选', '2', '中', '', 'ABC', '正式党员', '责任心强', '熟悉党的基本知识', '与入党积极分子关系密切', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('发展党员过程中，对发展对象进行政治审查，审查内容包括以下哪些？（ ）', '多选', '2', '中', '', 'ABCD', '对党的理论和路线、方针、政策的态度', '政治历史和在重大政治斗争中的表现', '遵纪守法和遵守社会公德情况', '直系亲属和与本人关系密切的主要社会关系的政治情况', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('发展党员过程中，政治审查的基本方法有以下哪些？（ ）', '多选', '2', '中', '', 'ABCD', '同本人谈话', '查阅有关档案材料', '找有关单位和人员了解情况', '必要的函调或外调', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党组织对发展对象进行集中培训，培训内容主要包括以下哪些？（ ）', '多选', '2', '中', '', 'ABC', '党的基本理论、基本路线、基本方略', '党的基本知识、党史、新中国史、改革开放史、社会主义发展史', '党的优良传统和作风', '如何撰写入党申请书', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('预备党员必须面向党旗进行入党宣誓，入党誓词包括以下哪些内容？（ ）', '多选', '2', '中', '', 'ABCD', '我志愿加入中国共产党', '拥护党的纲领，遵守党的章程', '履行党员义务，执行党的决定', '严守党的纪律，保守党的秘密', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('预备党员在预备期间，应履行以下哪些义务？（ ）', '多选', '2', '中', '', 'ABCD', '认真学习党的理论和路线、方针、政策', '自觉接受党组织的教育、管理和监督', '积极参加党的组织生活和党内活动', '认真完成党组织分配的任务', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党组织在发展党员过程中，要严格履行入党手续，以下哪些属于入党手续的环节？（ ）', '多选', '2', '中', '', 'ABCD', '递交入党申请书', '确定为入党积极分子', '确定为发展对象', '预备党员转正', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('入党申请书应包含以下哪些内容？（ ）', '多选', '2', '中', '', 'ABCD', '对党的认识', '入党动机和对待党的态度', '个人在政治、思想、学习、工作等方面的主要表现情况', '今后努力方向以及如何以实际行动争取入党', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党员教育主要内容包括（ ）。', '多选', '2', '中', '', 'ABCD', '政治理论教育', '党章党规党纪教育', '党的宗旨教育', '革命传统教育', '', '', '', '', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党支部运用 “三会一课” 制度对党员进行经常性教育管理，“三会一课” 指的是（ ）。', '多选', '2', '中', '', 'ABCD', '党员大会', '党支部委员会会议', '党小组会', '党课', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('组织生活会和民主评议党员的要求包括（ ）。', '多选', '2', '中', '', 'ABCD', '党支部每年至少召开 1 次组织生活会', '一般每年开展 1 次民主评议党员', '组织生活会要认真查摆问题，开展批评和自我批评', '根据民主评议情况和党员日常表现，对党员进行评定', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党员每年集中学习培训时间一般不少于 32 学时，培训方式可以有（ ）。', '多选', '2', '中', '', 'ABCD', '集中授课', '集体研讨', '在线学习培训', '实地参观学习', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('对新入党党员进行集中培训，培训内容重点包括（ ）。', '多选', '2', '中', '', 'ABCD', '党的基本知识', '党性党风党纪', '党的优良传统和作风', '党史、新中国史、改革开放史、社会主义发展史', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('民主评议党员时，党员对照（ ）进行党性分析。', '多选', '2', '中', '', 'AB', '合格党员标准', '入党誓词', '优秀党员标准', '岗位职责要求', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党员参加集中培训和集体学习情况，应作为（ ）的重要依据。', '多选', '2', '中', '', 'ABC', '民主评议党员', '评先评优', '考核奖惩', '职务晋升', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('各级党组织应当加强对党员教育管理工作的组织领导，为开展党员教育管理工作提供（ ）保障。', '多选', '2', '中', '', 'ABC', '人力', '财力', '物力', '制度', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党组织应当通过深入调研，及时发现、总结、推广党员教育管理工作的好经验好做法，具体措施有（ ）。', '多选', '2', '中', '', 'ABCD', '组织经验交流活动', '宣传先进典型', '开展示范培训', '建立长效机制', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('对党员教育管理工作中存在的问题，整改措施应做到（ ）。', '多选', '2', '中', '', 'ABCD', '明确整改责任', '规定整改时限', '确保整改落实', '加强整改监督', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('各级党组织要严格落实工作责任制，防止形式主义，具体要求包括（ ）。', '多选', '2', '中', '', 'ABCD', '明确工作目标', '完善工作制度', '加强督促检查', '严肃考核问责', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('“三重一大”事项包含（）。', '多选', '2', '中', '', 'ABCD', '重大决策', '重要人事任免', '重大项目安排', '大额度资金运作事项', '', '', '', '', '', '', '企业战略与经营管理', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('要建立健全贯彻落实习近平总书记重要指示批示的工作机制，加强统筹推进、系统联动、一贯到底，着力形成传达学习、（）、（）、（）、（）的工作闭环，确保事事有着落、件件有回音。', '多选', '2', '中', '', 'ABCD', '研究部署', '贯彻落实', '跟踪督办', '报告反馈', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党委前置研究讨论时重点研判决策事项是否（），是否（），是否（），是否（）。', '多选', '2', '中', '', 'ABCF', '符合党的理论和路线方针政策', '贯彻党中央决策部署和落实国家发展战略', '有利于促进企业高质量发展、增强企业竞争实力、实现国有资产保值增值', '有利于维护社会公众利益', '有利于维护职工群众合法权益', '有利于维护社会公众利益和职工群众合法权益', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党委要按照（）、（）、（）、（）的原则作出决策，实行科学决策、民主决策、依法决策。', '多选', '2', '中', '', 'ABCE', '集体领导', '民主集中', '个别酝酿', '多数酝酿', '会议决定', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('必须把坚持和加强党的领导与规范完善公司治理统一起来，坚持（）、（）、（）、（）的治理机制，将完善公司治理作为加强党的领导的重要内容，将支持各治理主体充分履职尽责作为加强党的领导的重要任务。', '多选', '2', '中', '', 'ABCE', '权责法定', '权责透明', '协调运转', '充分制衡', '有效制衡', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('请示报告的内容范围应包含（）。', '多选', '2', '中', '', 'AB', '覆盖党中央、中建集团党组、局党委有关文件精神要求', '《二级公司党组织向局党委请示报告事项清单》中事项', '通过正常决策流程决策的事项、常规性工作', '', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('公司领导基层联系点工作开展方式包含（）。', '多选', '2', '中', '', 'ABCDE', '公司领导人员建立与基层联系点的联系机制，以多种形式加强调研指导，每年深入基层联系点至少2次。', '公司领导人员应落实“一岗双责”，听取基层联系点单位全面从严治党情况汇报，并进行工作指导。', '公司领导人员每年应为基层联系点讲1次党课。', '公司领导人员可将基层联系点作为年度专题调研的被调研单位之一，在基层联系点开展相关调研工作。', '公司领导人员应帮助基层联系点解决1—2个突出问题，促进工作提升。', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('基层联系点选取原则包含（）。', '多选', '2', '中', '', 'ABC', '应坚持问题导向，以改革发展党建方面存在较多困难或具有典型意义、地域偏远的单位为重点。', '公司领导人员应带头建立党支部工作联系点。', '公司领导人员、各层级领导人员基层联系点一般不重复交叉，可与公司扶贫点、挂职地方和领导人员联系区域等相结合。', '就近原则，考虑离公司总部较近的单位。', '', '', '', '', '', '', '组织建设', '党建组织', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('各级党组织、业务部门的领导干部根据管理权限对下级相关人员进行经常性谈话，廉政谈话主体与对象包含（）。', '多选', '2', '中', '', 'ABCD', '党组织主要负责人对班子成员进行经常性提醒谈话。', '上级党组织主要负责人或其委托人在上级相关巡察、督导检查、审计检查等活动中对下级党组织主要负责人进行经常性提醒谈话。', '班子成员对其分管业务部门负责人、下级单位对应的分管领导进行经常性提醒谈话。', '部门负责人对本部门员工进行经常性提醒谈话。', '', '', '', '', '', '', '党风廉政建设', '党建廉政', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('廉政谈话记录的建立与管理，以下说法正确的是（）。', '多选', '2', '中', '', 'ABCE', '各级机构主要负责人和班子成员的谈话记录，由本单位党风廉政建设和反腐败工作牵头部门负责保管并建立台账。', '各级业务部门负责管理本部门的谈话记录和台账。', '各级干部人事部门负责本单位任职谈话记录的保管和台账的更新。', '各级党办部门负责每月收集各类谈话记录及台账，各类廉政谈话逢谈必记录。', '各级纪检机构负责本单位诫勉谈话记录的保管和台账的更新。相关部门按管理权限组织诫勉谈话后，将台账报本级纪检机构保管。', '', '', '', '', '', '党风廉政建设', '党建廉政', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('全面加强党的（  ），督促领导干部特别是高级干部（  ）、(  )、(  )，对违反党纪的问题，发现一起坚决查处一起。', '多选', '2', '中', '', 'ABCD', '纪律建设', '严于律己', '严负其责', '严管所辖', '', '', '', '', '', '', '党风廉政建设', '党建廉政', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('习近平在党的二十大报告中说，必须坚定不移走中国特色社会主义政治发展道路，坚持党的领导、人民当家作主、依法治国有机统一。加强人民当家作主制度保障，全面发展（   ），积极发展（   ），巩固和发展最广泛的爱国统一战线。', '多选', '2', '中', '', 'BC', '人民民主', '协商民主', '基层民主', '社会主义民主', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('《党章》规定,党的各级纪律检查委员会的主要任务是。（   ）', '多选', '2', '中', '', 'ABD', '检查党的路线、方针、政策和决议的执行情况', '维护党的章程和其他党内法规', '接受党员和群众的来信来访', '协助党的委员会加强党风建设和组织协调反腐败工作', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党组织应当保障党员的（    ）权利，鼓励和支持党员在党内监督中发挥积极作用。', '多选', '2', '中', '', 'AC', '知情权', '选举权', '监督权', '申诉权', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('《国有企业领导人员廉洁从业若干规定》规定，国有企业领导人员应当勤俭节约，不得有以下哪些职务消费行为（     ）', '多选', '2', '中', '', 'ABCD', '超出报履行国有资产出资人职责的机构备案的预算进行职务消费', '将履行工作职责以外的费用列入职务消费', '在特定关系人经营的场所进行职务消费', '不按照规定公开职务消费情况', '', '', '', '', '', '', '党风廉政建设', '党建廉政', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('《国有企业领导人员廉洁从业若干规定》规定，国有企业的（    ）为本企业实施本规定的主要责任人。', '多选', '2', '中', '', 'ACD', '党委（党组）书记', '纪委书记', '董事长', '总经理', '', '', '', '', '', '', '党风廉政建设', '党建廉政', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('领导班子主要负责人是职责范围内的党风廉政建设（   ），应当重要工作亲自部署、重大问题亲自过问、重点环节亲自协调、重要案件亲自督办。领导班子其他成员根据工作分工，对职责范围内的党风廉政建设负（    ）。', '多选', '2', '中', '', 'AB', '第一责任人', '主要领导责任', '连带责任', '主要责任', '', '', '', '', '', '', '党风廉政建设', '党建廉政', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('实行党风廉政建设责任制，要坚持集体领导与个人分工负责相结合，（   ），（   ），（   ）。', '多选', '2', '中', '', 'ABC', '谁主管、谁负责', '一级抓一级', '层层抓落实', '谁管理、谁负责', '', '', '', '', '', '', '党风廉政建设', '党建廉政', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('“一岗双责”中“一岗”就是一个领导干部的职务所对应的岗位；“双责”指一个领导干部既要对所在岗位应当承担的（  ）负责，又要对所在岗位应当承担的（   ）负责。', '多选', '2', '中', '', 'BC', '主体责任', '具体业务工作', '党风廉政建设责任制', '监督责任', '', '', '', '', '', '', '党风廉政建设', '党建廉政', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('《中建一局党风廉政建设责任制的规定》中明确，实施党风廉政建设责任追究，要实事求是，分清集体责任与个人责任，主要领导责任与直接领导责任，错误决策由领导干部个人决定或者批准的，不追究（   ）的责任。', '多选', '2', '中', '', 'AC', '领导班子', '领导干部个人', '具体执行者', '领导干部个人和具体执行者', '', '', '', '', '', '', '党风廉政建设', '党建廉政', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党委（党组）落实全面从严治党主体责任，应当遵循以下原则：（    ）', '多选', '2', '中', '', 'ABCD', '坚持紧紧围绕加强和改善党的全面领导', '坚持全面从严治党各领域各方面各环节全覆盖', '坚持真管真严、敢管敢严、长管长严', '坚持全面从严治党过程和成绩相统一', '', '', '', '', '', '', '党风廉政建设', '党建廉政', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('“两个维护”是指（   ）。', '多选', '2', '中', '', 'AD', '坚决维护习近平总书记党中央的核心、全党的核心地位', '坚决维护中国共产党的核心地位', '坚决维护中国共产党的领导', '坚决维护党中央权威和集中统一领导', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('《中国共产党宣传工作条例》中提到的宣传工作的根本任务包括哪些？', '多选', '2', '中', '', 'ABCDEF', '高举中国特色社会主义伟大旗帜', '巩固马克思主义在意识形态领域的指导地位', '巩固全党全国人民团结奋斗的共同思想基础', '建设具有强大凝聚力和引领力的社会主义意识形态', '建设具有强大生命力和创造力的社会主义精神文明', '建设具有强大感召力和影响力的中华文化软实力', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('公司在先进典型选树过程中，需要哪些部门或人员参与审核把关？', '多选', '2', '中', '', 'ABC', '纪检部门', '人事部门', '业务归口部门', '宣传部门', '', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('对重点项目进行重大宣传报道策划时需要做好（）', '多选', '2', '中', '', 'ABC', '对工程、技术做好充分了解', '挖掘1-3个传播点', '做好全面素材储备', '等媒体提供选题需求再说', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('媒体资源拓展的方法有（）', '多选', '2', '中', '', 'ABCD', '借助政府、企业等第三方力量', '积极参加属地交流活动', '两级总部联动对接协调', '依靠媒体中介', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('重点工程微信宣传稿撰写，可以从（）方面着手', '多选', '2', '中', '', 'ABCD', '科技创新', '质量管理', '安全管理', '智能建筑', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('宣传人员应具备（）能力', '多选', '2', '中', '', 'ABCD', '脑力', '眼力', '笔力', '脚力', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('会议照片里不能出现的是（）', '多选', '2', '中', '', 'ABC', '鲜花', '果盘', '烟灰缸', '纸巾', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('制作宣传视频时，以下哪些因素需要考虑？', '多选', '2', '中', '', 'ABCDE', '视频时长', '画面质量', '背景音乐选择', '旁白解说词', '拟投稿平台特点', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('宣传内容创作时，可以借鉴哪些方法？', '多选', '2', '中', '', 'ABCE', '讲述典型人物故事', '分享技术重难点', '展示项目优质质量', '抄袭其他项目内容', '结合热点事件进行创作', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('在选择宣传媒介时，可以考虑哪些类型？', '多选', '2', '中', '', 'ABDE', '电视台', '报纸', '网络自媒体', '行业网站', '企业融媒体', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目影像资料包括（）方面先进经验和做法', '多选', '2', '中', '', 'ABCDEF', '施工生产', '安全质量', '技术创新', '环境保护', '社会责任', '团队风貌', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('公司宣传思想工作的基本原则包括哪些？', '多选', '2', '中', '', 'ABDE', '坚持党管宣传，正面导向', '贴近国家大政方针', '追求高点击率', '坚持改革创新', '坚持三审三校责任制', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('《中建信条（2024版）》中，中国建筑的核心价值观包括哪些？', '多选', '2', '中', '', 'AB', '品质保障', '价值创造', '忠诚担当', '使命必达', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('《中建信条（2024版）》中提到的中国建筑的服务对象包括哪些？', '多选', '2', '中', '', 'ABCD', '用户', '员工', '股东', '社会', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('《中建信条（2024版）》中，中国建筑致力于实现的“五强”目标包括哪些？', '多选', '2', '中', '', 'ABCED', '价值创造力强', '创新引领力强', '品牌影响力强', '国际竞争力强', '文化软实力强', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('涉及一局领导新闻的报道需经过哪些流程？', '多选', '2', '中', '', 'ABC', '提前上报一局新闻线索', '上级单位同意批准', '公司对应业务口主管领导审核', '直接发布', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('宣传工作包括（）。', '多选', '2', '中', '', 'ABCDEF', '工程宣传', '人物宣传', '活动宣传', '形势宣传', '主题宣传', '成就宣传', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('五公司内部宣传平台包括（）', '多选', '2', '中', '', 'ABC', '微信', 'OA', '视频号', '报纸', '微博', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局宣传平台包括（）', '多选', '2', '中', '', 'ABCDEF', '微信', '网站', '视频号', '报纸', '微博', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目部应根据新近发生的新闻内容，有选择有针对性的主动向外界（）等媒体平台进行投稿。', '多选', '2', '中', '', 'ABCD', '电视台', '报纸', '网站', '杂志', '自媒体', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('典型选树宣传工作，按照（）的分级管理、分类组织原则开展。', '多选', '2', '中', '', 'ABC', '谁培养、谁推荐', '谁组织、谁总结', '谁审批、谁负责', '谁上报、谁宣传', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('公司遵循的文化体系包含（）', '多选', '2', '中', '', 'ABCD', '中建信条', '十典九章', '先锋文化', '鲁班文化', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('以下内容，可以向建设者报投稿的是（）', '多选', '2', '中', '', 'ABCDEF', '局主要领导公务活动', '国家级重磅荣誉', '重要工程节点通讯', '科技创新', '文化故事', '专项行动成效', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('意识形态工作责任制要求党委（党组）做到（ ）', '多选', '2', '中', '', 'ABC', '统筹协调本单位意识形态工作', '定期分析研判意识形态形势', '将意识形态工作纳入干部考核', '直接管理所有网络媒体平台', '', '', '', '', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('理论学习中心组学习应当坚持的原则有哪些？', '多选', '2', '中', '', 'ABCDE', '高举旗帜、凝心铸魂', '坚持围绕中心、服务大局', '坚持知行合一、学以致用', '坚持问题导向、注重实效', '坚持依规管理、从严治学', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('意识形态工作的主要内容包括哪些方面？', '多选', '2', '中', '', 'ABCD', '理论工作', '舆论宣传工作', '思想道德建设', '文化事业和文化产业发展', '', '', '', '', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('以下哪些属于公司“11336”战略发展思路的内容', '多选', '2', '中', '', 'ABCDE', '一个提高：提高政治站位', '一个基调：高质量发展', '三个驱动：转型驱动、创新驱动、文化驱动', '三个新格局：集团化发展新格局、数字化发展新格局、设计施工一体化发展新格局', '六个领先：企业治理领先、科技创新领先、资源管理领先、区域发展领先、品牌美誉领先、盈利能力领先。', '', '', '', '', '', '企业战略与经营管理', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局先锋文化包含以下哪些选项？', '多选', '2', '中', '', 'ACDE', '忠诚担当', '品质保障', '使命必达', '时代争锋', '品质为先', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中国建筑“一创五强”战略目标中，五强包括哪五强？', '多选', '2', '中', '', 'ABCDE', '价值创造力强', '创新引领力强', '国际竞争力强', '文化软实力强', '品牌影响力强', '', '', '', '', '', '企业战略与经营管理', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局“五力并举”战略路径包含以下哪些选项？', '多选', '2', '中', '', 'ABCDE', '提高党建引领力', '提高产业竞争力', '提高经营创效力', '提高企业治理力', '提高文化感召力', '', '', '', '', '', '企业战略与经营管理', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('新时代鲁班文化内涵中“担当”的具体要求包含', '多选', '2', '中', '', 'AB', '政治担当', '责任担当', '社会担当', '经济担当', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('新时代鲁班文化“超越”的具体要求包括', '多选', '2', '中', '', 'ACD', '超越历史', '超越行业', '超越自我', '超越对手', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('领导传播文化的场合包括', '多选', '2', '中', '', 'ABCD', '调研', '新生培训', '成长汇报会', '工会接待日', '', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('组织保障中的关键要求包括？', '多选', '2', '中', '', 'ABCE', '领导带头', '久久为功', '动态完善', '快速见效', '检查监督', '', '', '', '', '', '企业文化', '企业管理', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('公司 CI 工作领导小组的管理职责有？', '多选', '2', '中', '', 'ABC', '规范制定与落实', '确定创优计划', '组织培训', '具体实施 CI 工作', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('施工现场 CI 管理标准分为以下哪些等级？', '多选', '2', '中', '', 'ABC', '示范工程', '创优工程（金奖、银奖）', '达标工程', '优秀工程', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('必须达到 CI 创优标准的工程项目有？', '多选', '2', '中', '', 'ABC', '国家重点工程', '准备申报 “中国建筑优秀项目管理奖” 的工程', '对提升品牌形象具有重要意义的工程', '小型普通工程', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局在施项目 CI 规范实施指引包括以下哪些部分？', '多选', '2', '中', '', 'ABCD', 'CI 通用规范篇', 'CI 达标项目篇', 'CI 创优项目篇', 'CI 示范项目篇', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('以下哪些属于 CI 达标项目篇中外部形象展示的内容？', '多选', '2', '中', '', 'ABCD', '门楼式大门', '无门楼式大门', '门卫及门禁通道', '围墙', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('施工现场的安全警示类标志包括（ ）', '多选', '2', '中', '', 'ABCD', '禁止标志', '警告标志', '指令标志', '提示标志', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('五公司承接项目标识使用可选择以下哪些？', '多选', '2', '中', '', 'ABCD', '中建一局', '中建一局（集团）有限公司', '中建一局集团第五 建筑有限公司', '中建一局 五公司', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('施工图牌的主要内容包括以下哪些？', '多选', '2', '中', '', 'ABCD', '中国建筑一局标识', '工程简介', '项目组织机构图', '质量保证体系', '施工进度计划', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('机械设备形象中，哪些设备需要安装 “中国建筑” 标识？', '多选', '2', '中', '', 'ABCDE', '塔吊', '施工电梯', '施工灯架', '龙门吊', '砼罐', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('配电箱防护棚的要求包括？', '多选', '2', '中', '', 'ABCDE', '顶部采用双层硬防护', '底部设排水坡', '正面设置电箱管理制度责任图牌', '侧面设置安全标语', '外侧配备消防器材', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('安全警示标识的设置原则有？', '多选', '2', '中', '', 'ABD', '不应设置于移动物体上', '多个标志同时出现时按特定顺序排列', '颜色要鲜艳', '要设置在显眼位置', '标志大小要统一', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('茶水亭的设置要求有？', '多选', '2', '中', '', 'ABCD', '采用特定燃烧性能的材料搭建', '亭内设灭烟桶和灭火器', '配备电热水器且远离易燃易爆场所', '不得在塔吊回转半径内设置', '样式和尺寸固定', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('施工现场建筑垃圾站的要求包括（ ）', '多选', '2', '中', '', 'ABCDE', '应设封闭式垃圾站', '施工垃圾、生活垃圾及有毒有害废弃物应分类存放', '及时清运消纳', '悬挂垃圾房管理制度牌', '四周设置相关环保宣传画面', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('办公区山墙的相关规定有（ ）', '多选', '2', '中', '', 'ABC', '设置 “中国建筑” 中轴式组合', '蓝腰带侧边体现 “中国建筑一局” 标识', '房檐和踢脚线为蓝色，若无则刷蓝头、蓝脚', '室内门不可为灰白色', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('《十典九章》包括（ ）', '多选', '2', '中', '', 'AD', '行为十典，对全体员工关键行为和习惯的倡导及要求', '行为九典，对全体员工关键行为和习惯的倡导及要求', '礼仪十章，中国建筑员工的礼仪规范', '礼仪九章，中国建筑员工的礼仪规范', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('会议室设置中，正确的有（ ）', '多选', '2', '中', '', 'ABDE', '墙面、顶棚颜色为白色', '地面为地板或瓷砖', '窗帘为中建蓝且印有 “中国建筑一局” 标识', '会议桌两侧摆放桌旗（国旗与中国建筑集团有限公司司旗）', '会议室一侧设置落地旗（国旗与中国建筑集团有限公司司旗）', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('以下哪些部门需要悬挂《中建一局建设工程技术质量红线》（ ）', '多选', '2', '中', '', 'ABCDE', '工程部', '技术部', '质量部', '物资部', '商务部', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('生活区消防、防火管理制度的内容有（ ）', '多选', '2', '中', '', 'ABCDE', '严禁存放易燃易爆危险物品', '严禁使用电饭煲等炊事用具', '严禁在床上吸烟、乱扔烟头', '宿舍走廊保持畅通', '每层设置一组通用型干粉灭火器', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('文明宿舍管理制度的规定有（ ）', '多选', '2', '中', '', 'ABCDE', '注意个人卫生，不准随地吐痰', '建立室长负责制，清理打扫宿舍', '爱护公共财物，不得乱涂乱画', '严禁私拉乱接电线和使用电加热器具', '严禁男女混居、赌博等行为', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局食堂文化图牌的材质可以是（ ）', '多选', '2', '中', '', 'ABC', 'KT 板加银包边', 'PVC', '亚克力', '', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局食堂工作人员需做到 “四勤”，包括（ ）', '多选', '2', '中', '', 'ABCD', '勤理发', '勤洗澡', '勤换衣', '勤剪指甲', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局食堂管理制度中，对食堂卫生的要求有（ ）', '多选', '2', '中', '', 'ABCD', '干净整洁、无异味', '无蚊蝇、老鼠、蟑螂', '卫生不留死角', '生熟分开', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中建一局卫浴区管理制度中，包括（ ）', '多选', '2', '中', '', 'ABCD', '设施符合规定', '冬季确保热水供应', '专人负责保洁', '浴室内无异味、积水', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('党建品牌规范涉及的内容有？', '多选', '2', '中', '', 'AB', '党员活动室铜牌、门牌', '建证释义墙', '廉洁文化理念释义墙', '项目书记及经理室廉洁图牌', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('创优项目外侧品牌墙的设置要求有？', '多选', '2', '中', '', 'ABC', '主大门总宽度 10m，净内空 8m，高度 6.5m；门楣尺寸：长 10 x 高 1.5m；标识高度 1m', '“中建 X 号门” 要在大门左门柱蓝色位置上下左右居中放置', '常规情况下品牌墙画面尺寸：6.75 x 4.5m；有厢房一侧画面尺寸：6.75 x 3.5m', '左侧为中建一局 “一最五领先” 战略目标；右侧为中建一局 “五力并举” 战略路径', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('办公区临建在材质选择上，可采用？', '多选', '2', '中', '', 'ABC', '铝扣板格栅', '钢架铁皮字', '钢架喷绘布面', '木质材料', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('安全教育讲评台主背景画面需体现的内容有？', '多选', '2', '中', '', 'ABCD', '“中建一局安全” 标识', '高处作业 “十个必须”', '安全生产 “十项禁令”', '行为安全 “七步法”', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('安全教育体验馆内可设置的安全体验设施有？', '多选', '2', '中', '', 'ABCDE', '劳保用品展示', '安全帽撞击', '综合用电', '洞口坠落', '平衡木体验', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('关于先锋文化墙的设置，说法正确的有？', '多选', '2', '中', '', 'AD', '根据参观路线顺序设置正反方向', '尺寸固定不变', '材质统一规定', '施工现场必须设置', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('样板展示区大门固定标语内容有？', '多选', '2', '中', '', 'AC', '品质为先 打造质量样板', '安全第一 预防为主', '时代争锋 创建精品工程', '科技创新 引领未来', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('以下哪些位置可设置发光标识？', '多选', '2', '中', '', 'ABCD', '门楼式大门门楣', '塔吊', '品牌布', '办公区办公楼体', '', '', '', '', '', '', 'CI工作', '其他', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('新闻危机处置要做到（   ）。', '多选', '2', '中', '', 'ABCD', '有利于维护社会稳定', '有利于维护公司利益', '有利于公司持续、健康和快速发展', '有利于应急及后续活动的顺利开展', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('研判为Ⅲ级（黄色预警）舆情事件主要依据是（）。', '多选', '2', '中', '', 'ABCD', '中建集团四级舆情（一般级事件）', '地市级媒体、行业官方微博/微信公众号/纸媒、政府部门处罚文件等首发报道事件', '认证微博或自媒体账号（粉丝量大于5万）参与信息讨论或转发', '事件本身及媒体报道均围绕“中建一局”展开，对企业品牌形象产生较大程度的负面影响', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('研判为IIII级（蓝色预警）舆情事件主要依据是（  ）。', '多选', '2', '中', '', 'AD', '个人在论坛、微博、微信、博客、QQ空间等发布的消息，转发超过50次，评论次数超过500次', '地市级媒体、行业官方微博/微信公众号/纸媒、政府部门处罚文件等首发报道事件', '认证微博或自媒体账号（粉丝量大于5万）参与信息讨论或转发', '对企业品牌形象产生一定程度的负面影响', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('研判为I级（红色预警）舆情事件主要依据是（ ）。', '多选', '2', '中', '', 'ABCDE', '中建集团一级舆情（特别重大级事件）', '中央级等主流媒体（含报刊、电视台、网站、新闻客户端、微信公众号、微博账号、视频网站及应用等）首发负面报道', '认证微博（粉丝量大于100万）、知名自媒体账号集中参与信息讨论或转发', '事件本身及媒体报道均围绕“中建一局”展开，对企业品牌形象产生特别重大程度的负面影响', '中建集团二级舆情（重大级事件）', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('《中国建筑一局（集团）有限公司新闻危机管理办法》编制依据主要有（）。', '多选', '2', '中', '', 'ABD', '《中国建筑集团有限公司重大突发（危机）事件新闻发布管理办法》', '《中国建筑舆情应对指导手册》', '《安全生产管理管理办法》', '《中国建筑舆情应对案例库》', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('面对突发事件，项目部应采取（     ）措施。', '多选', '2', '中', '', 'ABCDE', '第一时间（30分钟内）向公司报告有关情况', '抓好现场的控制，对企业标识、名称等品牌元素进行保护性处理', '迅速稳定员工及民工队伍，立即进入应急处置程序', '在上级领导尚未到达现场前，由项目部新闻发言人做好现场媒体的友好接洽与沟通', '在征得上级单位同意后，及时与当地政府有关部门进行联系，争取帮助', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('新闻危机处置需要做到（    ）', '多选', '2', '中', '', 'ABCD', '有利于维护社会稳定', '有利于维护公司利益', '有利于公司持续、健康和快速发展', '有利于应急及后续活动的顺利开展', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('某项目房屋因自然灾害导致部门外墙保温层脱落及个别门窗损坏，舆论质疑企业产品质量问题。应及时备好汇报、媒体备答、公开回应通用口径（      ）：', '多选', '2', '中', '', 'ABCD', '针对民众反映的X项目房屋质量问题，经核实，XX项目于XXXX年通过验收合格后交付使用。', 'XXXX年XX月XX日，XX市发生XX灾害，最大级别为X级，可能引发房屋外观脱落、裂缝等情况。', '经XX部门及第三方检测结果认定，XX项目部分外墙保温层脱落及个别门窗损坏系自然灾害导致，非工程质量问题。', '公司秉承负责任的精神，将采取以下措施，为业主提供帮助：一是组织专业人员对XX项目存在的安全隐患进行全面排查；二是XXXX，……。', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('网传某公司应届生校招签约后进行大范围毁约、降薪，公司需要如何回应（    ）：', '多选', '2', '中', '', 'ABCE', '公司已与XX名应届毕业生签署三方协议，对于已签合约，公司全部认可，不存在劝退、毁约情形。', '因XX原因，需对X名签约应届生进行岗位调整，调整比例不超过X%。', '公司将本着公平公正原则，优先进行岗位自选，然后按照笔试、面试成绩排名进行面谈，调岗、定薪完全尊重已签约人员意愿。', '现在的毕业生真是难伺候，有个工作就不错了。', '如有此前签约人员因此与我公司解约，公司将按协议规定进行经济赔偿。', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('2022年5月12日，有抖音账号发布消息称，“A公司承建的B小区建筑外观装饰年久失修坠落，造成人员受伤、车辆被砸……”相关内容引起大量网民关注并留言评论。物业公司应如何回应（        ）:', '多选', '2', '中', '', 'ABCD', '5月12日14时左右，B小区8号楼发生墙皮坠落事件，造成1人擦伤、2车被砸，受伤人员已送医治疗，受损车辆也已安排维修。对此，我们深感歉意。', '事件发生后，物业工作人员第一时间对相关区域进行安全警戒，并派遣专业人员对8号进行加固（修理），整修工作已于XX日XX时XX分完成。', '经调查核实，XX部位坠落原因为年久失修自然脱落。未来一周，物业部门将组织专业力量，对辖区所有楼栋进行全面安全风险排查与整改，切实保障业主和公众安全。', '对于造成的相关损失，我们已就赔偿问题与业主达成共识。', '对于造成的相关损失，需要找建筑公司承担，你们找他们去。', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('某工程项目因自然灾害引发人员伤亡，涉事公司需围绕以下内容，备好应答口径（        ）：', '多选', '2', '中', '', 'ABCD', 'XX月XX日，XX地出现XX灾害，XX项目出现XX问题，造成X人受伤/死亡，XX损坏。目前，该项目已全面停工。', '事件发生后，我公司积极配合XX政府部门开展应急救援工作，项目员工和周边居民的疏散和安置工作正在有序进行中（或已于XX日XX时完成）。', '我们已组织专业人员对项目安全隐患进行全面排查。', '出于对员工及周边居民的安全考虑，XX项目将关闭至XX月XX日，项目部将保留应急和维抢修人员。', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('2020年5月13日，有微博账号发布消息称，“A公司承建的即将交付的B安置小区部分楼栋墙体开裂。网友上传的图片显示，部分楼体的外墙、地面等均可见开裂现象”。相关内容引起大量网民关注并留言评论，舆论焦点指向A公司。在工程质量情况尚未查明的情况下，A公司应如何回应（             ）:', '多选', '2', '中', '', 'ABD', '对于大家关注的B安置小区工程质量问题，我公司高度重视，已于5月13日成立专项调查小组，开展内部调查。', '我们积极配合政府XX部门开展调查，最终结论以XX部门的调查结果公告为准。', '网上的照片都是假的，是有人恶意抹黑我们央企。', '工程质量关乎公众生命安全，若工程确实存在质量问题，我公司将坚持实事求是的原则和科学公正的态度，依法依规严肃处理。感谢社会各界的监督。', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('公司员工因XXX被追究刑事责任，被媒体报道并质疑公司管理，事件被舆论广泛关注，并关联企业管理、企业文化等，企业可通过自有官方渠道（官网、微博、微信等）进行公开回应（    ）:', '多选', '2', '中', '', 'ABCD', '公司获悉XX人员因XXX被追究刑事责任后，立即启动调查程序。经调查，相关情况属实。', '鉴于事件性质恶劣、情节严重，损害公司声誉和形象，根据公司XX规定，于XXXX年XX月XX日给予该员工辞退处分。', '公司将进一步加强员工管理和监督工作，增强员工遵纪守法意识，对违法违纪的行为坚决从严处理。', '欢迎社会各界的监督。', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('工程质量类舆情的特征是？', '多选', '2', '中', '', 'ABCD', '舆情潜伏期短，舆论关注度高', '传播形式多样，易引发群体性事件', '影响范围大', '具有连带性', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('关于某项目发生的讨薪事件，以下哪些行为可能会加剧舆情危机？（ ）', '多选', '2', '中', '', 'ABCE', '相关部门对讨薪事件不闻不问，不采取任何行动。', '项目负责人拒绝回应媒体采访。', '网上出现一些不实信息时，相关方面不及时辟谣。', '相关部门迅速组织协调会，邀请工人代表、企业代表共同商讨解决方案。', '项目负责人指责工人恶意讨薪。', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('在项目结算纠纷引发舆情的情况下，以下哪些行为可能会使舆情进一步恶化？（ ）', '多选', '2', '中', '', 'ABCE', '双方在公开场合互相攻击、指责。', '拒绝与媒体沟通，对舆情置之不理。', '故意隐瞒项目结算中的关键信息。', '积极寻求法律途径解决纠纷，并向公众说明情况。', '私下与部分利益相关者达成妥协，而不公开解决方案。', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('舆情应急管理工作的原则包括（）：', '多选', '2', '中', '', 'ABCD', '联防联控，协同处置', '快速反应，科学应对', '真诚沟通，统一口径', '预防为主，闭环管理', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('2025年3月，某工程项目在移交业主单位后，业主单位引发了环保问题，导致某工程项目的总包单位被属地政府通报，面对这种情况，以下哪些口径是正确的（）：', '多选', '2', '中', '', 'ABCD', '接到政府单位通报信息后，公司高度重视。', '经核实，被通报工程已于2023年某月某日全面移交至A业主单位。', '现该工程归A业主单位运营管理，我单位现已无权属。', '对于本次通报，我公司已向执法部门提交相关证明材料进行申诉', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('新闻危机处置要做到“四个有利于”，即（）：', '多选', '2', '中', '', 'ABCD', '有利于维护社会稳定', '有利于维护公司利益', '有利于公司持续、健康和快速发展', '有利于应急及后续活动的顺利开展', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('2022年4月，某项目被检查发现备案的项目经理与项目的实际负责人不符，引发网络关注，作为新闻发言人，以下口径合适的是（）：', '多选', '2', '中', '', 'ABCD', '感谢您对我司的关注。经核实，项目经理张三因个人原因无法正常参与本工程管理。', '为保证本项目正常履约，3月1日我方向业主单位提出项目经理变更意向，并征得业主同意后指派具有同等执业资格和资历的李四（实际负责人）到本项目履职。', '目前，项目经理变更资料已收集完成，预计4月3日上报属地主管部门完成变更手续。', '项目经理变更期间，为保证业主方利益不受侵害，切实履行我方管理责任，我方要求张三（备案项目经理）在变更手续完成前，持续关注本项目动态，与计划变更人员共同承担本项目管理责任。', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('新闻危机分为四个等级，其中Ⅱ级为橙色预警，下列哪些为橙色预警的特征（）：', '多选', '2', '中', '', 'ABD', '省部级等主流媒体（含报刊、电视台、网站、新闻客户端、微信公众号、微博账号、视频网站及应用等）首发负面报道。', '认证微博或知名自媒体账号（粉丝量大于50万）参与信息讨论或转发。', '对企业品牌形象产生较大程度的负面影响。', '对企业品牌形象产生重大程度的负面影响。', '认证微博（粉丝量大于100万）、知名自媒体账号集中参与信息讨论或转发。', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('对于安全生产类的风险描述，以下正确的是（）：', '多选', '2', '中', '', 'ABC', '由意外、人员操作不当或其他原因引发火情、爆燃、设备倒塌等安全事件，可能伴随人员伤亡，事件被媒体或网民关注引发讨论', '工程项目发生安全事件，我方非事件责任主体，被媒体关联报道。', '工程项目存在安全隐患，被监管部门通报，引发媒体报道或关联同期安全生产事件。', '工程项目没有安全风险，但被“有心”媒体利用，断章取义、诬陷造谣。', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('在新闻危机应急处置当中，要按照新闻媒体记者对事件介入的时间，分为（）四种情况进行处置。', '多选', '2', '中', '', 'BCDE', '媒体采访前', '到达现场前', '到达现场后', '发布信息前', '发布信息后', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('2023年8月，某民用住宅项目因业主的资金链断裂而被迫停工，大量媒体对该工程进行报道，报道中提到中建一局不履行央企责任与担当，该项目所属的子企业立即召开新闻发布会，如果你是公司的新闻发言人，面对发布会上记者的提问，你该怎么回答（）：', '多选', '2', '中', '', 'ABCD', '针对您提到的问题，我司第一时间进行了核查。', '该项目的停工主要是业主方面资金链断裂导致，我司自该项目开工以来，一直严把工程质量、强化工期意识，履行央企责任。', '目前，我司正在与业主方积极进行沟通协商，后续开工情况将及时向外界披露。', '欢迎您继续对我司保持关注。', '', '', '', '', '', '', '舆情工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('基层工会干部队伍建设的要求包括哪些？', '多选', '2', '中', '', 'ABCDE', '依法依规推进民主选举', '积极稳妥、确保质量', '争取公益性岗位', '市场化、社会化方式聘用', '提高履职能力', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('工会经费可以用于哪些支出？', '多选', '2', '中', '', 'ABCDEF', '职工活动支出', '职工教育支出', '工会干部培训', '工会行政支出', '维权支出', '补助下级工会', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('下列哪些做法可以增强基层工会的吸引力和凝聚力？', '多选', '2', '中', '', 'ABCD', '加强工会组织建设', '提高工会干部素质', '开展丰富多彩的文体活动', '维护职工合法权益', '加强与企业的沟通协调', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('下列哪些做法可以提高工会工作的规范化水平？', '多选', '2', '中', '', 'ABCD', '制定和完善工会工作制度', '加强工会干部培训', '推广工会工作先进经验', '加强对工会工作的监督检查', '开展工会工作创新活动', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('工会会员应享有的权利有哪些？', '多选', '2', '中', '', 'ABC', '选举权与被选举权', '对工会工作进行监督', '提出意见和建议', '随意退出工会', '', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('固定资产一般包括哪些？', '多选', '2', '中', '', 'ABCD', '房屋及建筑物', '专用设备', '一般设备', '文物和陈列品', '图书、档案', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('送温暖资金的使用对象包括哪些？', '多选', '2', '中', '', 'ABD', '困难职工', '伤病残职工', '节日慰问职工', '遭受突发灾害的职工', '退休职工', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目工会经费的报销范围包括哪些？', '多选', '2', '中', '', 'ABCD', '职工活动费用', '职工教育费用', '职工福利费用', '职工慰问费用', '办公费用', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目职工之家建设标准中，关于着装的要求包括哪些？', '多选', '2', '中', '', 'ABC', '统一着装', '整洁干净', '符合安全规范', '体现企业文化', '美观大方', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目职工之家建设标准中，关于内务卫生的要求包括哪些？', '多选', '2', '中', '', 'ABC', '地面整洁', '物品摆放有序', '空气清新', '定期消毒', '无噪音污染', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目职工之家建设标准中，关于住宿的要求包括哪些？', '多选', '2', '中', '', 'ABD', '安全舒适', '设施齐全', '环境优美', '管理规范', '价格实惠', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('项目职工之家建设标准中，关于厨房及餐厅的要求包括哪些？', '多选', '2', '中', '', 'ABC', '设施齐全', '卫生干净', '菜品丰富', '服务周到', '', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('工会女职工工作的主要任务包括哪些？', '多选', '2', '中', '', 'ABCDE', '维护女职工合法权益', '提高女职工素质', '促进女职工参与企业管理', '关心女职工生活', '推动女职工事业发展', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('工会评选表彰工作的原则包括哪些？', '多选', '2', '中', '', 'ABCD', '公平公正', '公开透明', '严格程序', '注重实效', '鼓励创新', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('劳务派遣工加入工会的规定有哪些？', '多选', '2', '中', '', 'AC', '派遣单位与用工单位应共同组织', '派遣单位或用工单位单独组织均可', '工会应主动吸纳劳务派遣工', '无特定规定', '', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('职工互助保障活动在哪些方面发挥了重要作用？', '多选', '2', '中', '', 'ABD', '维护职工保障权益', '促进社会和谐稳定', '提高企业经济效益', '密切工会与职工联系', '', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('以下哪些属于职工互助保障活动的特点？', '多选', '2', '中', '', 'ABD', '公益性', '非营利性', '高风险性', '广泛参与性', '', '', '', '', '', '', '工会工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团支部成立的条件包括（）。', '多选', '2', '中', '', 'ABCD', '有团员3人以上', '经上级团组织批准', '单位党组织同意', '提交书面申请', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团支部开展组织生活的内容包括（）。', '多选', '2', '中', '', 'ABD', '三会两制一课', '主题团日', '商业合作洽谈', '团员评议', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团支部服务青年的方式包括（）。', '多选', '2', '中', '', 'ABD', '开展文体活动', '反映青年诉求', '提供就业培训', '组织政治学习', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团的建设必须贯彻的基本要求包括（）。', '多选', '2', '中', '', 'ABD', '坚持党的基本路线', '坚持民主集中制', '坚持自由选举', '加强基层建设', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团的民主集中制原则包括（）。', '多选', '2', '中', '', 'ABD', '少数服从多数', '下级服从上级', '直接任命干部', '集体领导与个人分工结合', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团的干部需具备的品德包括（）。', '多选', '2', '中', '', 'ABD', '清正廉洁', '团结同志', '形式主义', '自我批评', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团的纪律处分类型有（）。', '多选', '2', '中', '', 'ABCE', '警告', '严重警告', '留团察看', '降级处分', '开除团籍', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中国共产主义青年团是（）。', '多选', '2', '中', '', 'ABC', '中国共产党领导的先进青年的群众组织', '广大青年在实践中学习中国特色社会主义和共产主义的学校', '中国共产党的助手和后备军', '建设社会主义和共产主义的预备队', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团员在团内有（）权利。', '多选', '2', '中', '', 'ABD', '选举权', '被选举权', '监督权', '表决权', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团员的义务包括（）。', '多选', '2', '中', '', 'ABCDE', '学习理论知识', '自觉遵守国家的法律法规和团的纪律', '接受国防教育', '虚心向人民群众学习', '开展批评和自我批评', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团员的权利包括（）。', '多选', '2', '中', '', 'ABCD', '参加团的有关会议', '参加团组织开展的各类活动', '向团的任何一级组织提出请求', '向团的任何一级组织申诉', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团支部的基本任务包括（ ）。', '多选', '2', '中', '', 'ABD', '组织理论学习', '执行党团决议', '开展商业活动', '培育社会主义核心价值观', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('联合团支部的组建原则包括（ ）。', '多选', '2', '中', '', 'ABC', '地域相邻', '便于管理', '行业相近', '随机分配', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团支部的换届程序要求（ ）。', '多选', '2', '中', '', 'ABD', '同级党组织同意', '上级团委批复', '团员自发组织', '1个月内报备', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团支部的基本任务是（ ）。', '多选', '2', '中', '', 'ABCD', '了解、反映团员和青年的思想', '向团员、青年通报团的工作情况', '团结带领青年在促进经济社会发展中发挥生力军和突击队作用', '学习科学、文化、法律', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('中国青年五四奖章的评选条件包括哪些？', '多选', '2', '中', '', 'ABC', '坚决拥护中国共产党的领导', '获得过省级以上荣誉', '具有突出的工作实绩', '拥有高学历背景', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('申报“优秀共青团干部”需满足哪些条件？', '多选', '2', '中', '', 'ABC', '‌政治条件', '工作年限', '工作表现', '民主推荐', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('青年岗位能手的核心标准是？', '多选', '2', '中', '', 'ABD', '政治素质', '专业能力', '工龄要求', '工作实绩', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('新时代共青团员要做的模范包括哪些？', '多选', '2', '中', '', 'ABCD', '理想远大、信念坚定', '刻苦学习、锐意创新', '敢于斗争、善于斗争', '艰苦奋斗、无私奉献', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团员教育评议制度的主要内容包括哪些？', '多选', '2', '中', '', 'ABC', '学习教育', '自我评价', '组织评议', '表彰奖励', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('“党建带团建”工作的指导思想包括哪些？', '多选', '2', '中', '', 'ABC', '习近平新时代中国特色社会主义思想', '新时代党的建设总要求', '增强“四个意识”，坚定“四个自信”，做到“两个维护”', '提高企业经济效益', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('共青团青年人才培养工作的基本原则包括（）。', '多选', '2', '中', '', 'ABCD', '坚持党管人才', '突出政治引领', '强化统筹协调', '创新服务载体', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('"青马工程"的重点培养措施是（）。', '多选', '2', '中', '', 'ABCD', '规范课程体系', '开发社会实践基地', '实行动态淘汰制', '建立学员信息库', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('发挥团员先锋作用的具体举措包括（）。', '多选', '2', '中', '', 'ACD', '岗位建功', '彰显身份', '理论学习', '志愿服务', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团员发展质量保障措施包括（）。', '多选', '2', '中', '', 'ACD', '做实培养', '扩大规模', '日常考察', '严格程序', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团员教育评议的环节包括（）。', '多选', '2', '中', '', 'ABC', '学习教育', '自我评价', '组织评议', '群众测评', '', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO multiple_choice_questions (question_stem, question_type, score, difficulty, analysis, answer, option_a, option_b, option_c, option_d, option_e, option_f, option_g, option_h, option_i, option_j, primary_tag, secondary_tag, created_at)
VALUES ('团费使用范围包括（）。', '多选', '2', '中', '', 'ABDE', '培训团员', '购买团旗', '团干部福利', '补助困难团', '基层活动', '', '', '', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('“三重一大”事项指重大决策、重要人事任免、（ ）和大额度资金运作事项。', '1', '中', '', '', '企业战略与经营管理', '企业管理', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('“三重一大”等重要事项在决策前必须经过本单位党委（ ）。', '1', '中', '', '', '企业战略与经营管理', '企业管理', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('中央八项规定强调要改进调查研究、精简会议活动、精简文件简报、规范出访活动、改进警卫工作、改进新闻报道、（ ）、厉行勤俭节约。', '1', '中', '', '', '党风廉政建设', '党建廉政', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党风廉政建设，党委要负主体责任，纪委要履行好（ ）。', '1', '中', '', '', '党风廉政建设', '党建廉政', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('“一岗双责”中的“双责”指既要对所在岗位应当承担的具体业务工作负责，又要对所在岗位应当承担的（ ）负责。', '1', '中', '', '', '党风廉政建设', '党建廉政', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('“两个一以贯之”指坚持党对国有企业的领导是重大政治原则，必须一以贯之；建立（ ）是国有企业改革的方向，也必须一以贯之。', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('“两个确立”指确立习近平同志党中央的核心、全党的核心地位，确立（ ）的指导地位。', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('“两个维护”指坚决维护习近平总书记党中央的核心、全党的核心地位，坚决维护（ ）。', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('“四个意识”指政治意识、（ ）、核心意识、看齐意识。', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('“四个自信”指道路自信、理论自信、制度自信、（ ）。', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('中建集团“一个提高”指提高（ ）。', '1', '中', '', '', '企业文化', '企业管理', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('中建集团“六个塑强”包括塑强房建首位优势、塑强基建支柱优势、塑强地产卓越优势、塑强设计领先优势、（ ）、塑强业态融合优势。', '1', '中', '', '', '企业文化', '企业管理', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('中建一局先锋文化以“（ ）”为精神内核，以“品质为先、时代争锋”为行动标准。', '1', '中', '', '', '企业文化', '企业管理', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('中建一局“155大党建工作格局”中第一个“5”即两级党组织要全面履行“五项职能”，包括抓战略、掌全局，抓班子、带队伍，抓文化、塑品牌，（ ），抓自身、创价值。', '1', '中', '', '', '企业文化', '企业管理', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('中建一局项目党支部“五个价值创造点”包括组织建设、目标完成、制度执行、（ ）、廉洁从业。', '1', '中', '', '', '企业文化', '企业管理', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('中建一局五公司“鲁班文化”中的“担当”包括政治担当、（ ）、业务引领担当。', '1', '中', '', '', '企业文化', '企业管理', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('领导干部“五位一体”能力素养包括政治方向、价值取向、工作激情、（ ）、优良品格。', '1', '中', '', '', '企业文化', '企业管理', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('中建集团“一创五强”战略目标是以创建具有全球竞争力的世界一流企业为牵引，致力成为价值创造力强、国际竞争力强、行业引领力强、（ ）、文化软实力强的世界一流企业集团。', '1', '中', '', '', '企业战略与经营管理', '企业管理', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('中建一局“1135”战略体系中锁定的1个目标是（ ）。', '1', '中', '', '', '企业战略与经营管理', '企业管理', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('中建一局“五力并举”战略路径包括提高党建引领力、提高产业竞争力、提高经营创效力、提高企业治理力、（ ）。', '1', '中', '', '', '企业战略与经营管理', '企业管理', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记指出：“中国特色社会主义最本质的特征是（）。', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记指出：“江山就是人民、人民就是江山，打江山、守江山，守的是（）。', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('把人民对美好生活的向往作为（）。', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('坚持以党的（）引领社会革命。', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('习近平总书记指出：“党风问题关系执政党的（）。', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('坚持一切为了人民、一切（）。', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('作风问题本质上是（）。', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('我们党从制定和落实（）破题，提出和落实新时代党的建设总要求 。 ', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('坚持把（）放在首位，做深做实干部政治素质考察，突出把好政治关、廉洁关 。', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('中国共产党以马克思列宁主义、毛泽东思想、邓小平理论、“三个代表” 重要思想、科学发展观、（  ）作为自己的行动指南。', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党的最高理想和最终目标是实现（ ）。', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党的思想路线是一切从实际出发，理论联系实际，（ ），在实践中检验真理和发展真理。', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党员如果没有正当理由，连续（  ）不参加党的组织生活，或不交纳党费，或不做党所分配的工作，就被认为是自行脱党。', '1', '中', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('预备党员的预备期为（  ）。', '1', '中', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党的基层组织是党在社会基层组织中的（），是党的全部工作和战斗力的基础。', '1', '中', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('中国共产党党徽为______和______组成的图案。', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('新形势下加强和规范党内政治生活，必须以______为根本遵循。 ', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('项目党支部“三会一课”中的“三会”指______、______、______。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党员必须自觉遵守党的纪律，首先是党的______和______。 ', '1', '中', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('中国共产党的宗旨是____。', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('中国共产党的最高理想和最终目标是____。', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党的基层组织设立的委员会的书记、副书记的产生，由上届委员会提出候选人，报上级党组织审查同意后，在委员会（ ）上进行选举。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('选举采用（ ）投票的方式。选票上的候选人名单以姓氏笔画为序排列。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('选举人不能写选票的，可以由本人委托（ ）按照选举人的意志代写。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党的基层组织设立的委员会的书记、副书记候选人，由（ ）提出，报上级党组织审查同意。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党的基层组织设立的委员会的选举，如果得票超过半数的被选举人多于应选名额时，以（ ）多少为序，至取足应选名额为止。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党的基层组织进行选举时，候选人获得赞成票超过（ ）的，始得当选。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党的基层组织设立的委员会召开党员大会进行选举时，由（ ）向党员大会报告上届委员会的工作。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('《中国共产党国有企业基层组织工作条例 （试行）》指出，国有企业党组织必须高举中国特色社会主义伟大旗帜，以马克思列宁主义、毛泽东思想、邓小平理论、“三个代表”重要思想、科学发展观、（ ）为指导。
答案：习近平新时代中国特色社会主义思想', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('国有企业党支部（党总支）以及不设支部委员会的党支部书记、副书记，每届任期（ ）年。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('国有企业党员人数 3 人以上、50 人以下的，经上级党组织批准，设立（ ）。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('国有企业党组织应当按照（ ）原则，集体讨论决定重大事项。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('国有企业基层党组织应当按期换届。任期届满前（ ）个月，应当书面报告上级党组织。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('国有企业基层党组织设置调整和撤销，必须经（ ）批准。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('国有企业党支部（党总支）发挥（ ）作用，围绕生产经营开展工作。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部设置一般以单位、区域为主，以（ ）为主要方式。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('正式党员不足 3 人的单位，应当按照地域相邻、行业相近、规模适当、便于管理的原则，成立（ ）党支部。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部委员会由党支部党员大会选举产生，党支部书记、副书记一般由党支部委员会会议选举产生，不设委员会的党支部书记、副书记由党支部党员大会（ ）产生。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('有正式党员 7 人以上的党支部，应当设立党支部委员会。党支部委员会由 3 至 5 人组成，一般不超过（ ）人。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部书记主持党支部全面工作，督促党支部其他委员履行职责、发挥作用，抓好党支部委员会（ ）建设，向党支部委员会、党员大会和上级党组织报告工作。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部应当组织党员按期参加党员大会、党小组会和上党课，定期召开（ ）会议。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部委员会会议一般每月召开（ ）次，根据需要可以随时召开，对党支部重要工作进行讨论、作出决定等。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党小组会一般每月召开（ ）次，组织党员参加政治学习、谈心谈话、开展批评和自我批评等。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党课每季度至少开展（ ）次。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('对经党组织同意可以不转接组织关系的党员，所在单位党组织可以将其纳入一个党支部或者（ ）进行管理。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部要深入践行中建一局（ ）大党建工作格局。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('项目党支部充分发挥 “（ ）” 作用。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('基层党支部要深植先锋文化和（ ）。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部设置要落实 “四同步”“四对接” 要求，确保党的组织和工作（ ）。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部设置形式包括单独成立党支部、联合党支部以及（ ）。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('凡是有正式党员（ ）人以上的，都应当成立党支部。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党员人数（ ）人以上、100 人以下的，设立党的总支部委员会。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('正式党员超过 3 人且相对固定的单位应（ ）成立党支部。
', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('为期（ ）个月以上的工程、工作项目等，符合条件的，应单独成立党支部。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('正式党员不足 3 人的单位，应当按照地域相邻等原则，与其他单位成立（ ）。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('联合党支部覆盖单位一般不超过（ ）个。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部的成立，一般由基层单位提出申请，上级党委召开会议研究决定并批复，批复时间一般不超过（ ）个月。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('临时党支部主要组织党员开展政治学习，教育、管理、监督党员，对（ ）进行教育培养等。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('有正式党员（ ）人以上的党支部，设立党支部委员会。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部委员会由 3 至 5 人组成，一般不超过 7 人；党总支委员会一般设委员 5 至 7 人，最多不超过（ ）人。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部书记、副书记一般由党支部委员会会议选举产生，不设委员会的党支部书记、副书记由（ ）选举产生。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('换届选举时，有选举权的到会党员数超过应到会有选举权党员数的（ ）方可开会。
', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('被选举人获得的赞成票超过应到会有选举权的党员数的（ ），始得当选。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('对因党员人数或者所在单位、区域等发生变化，不再符合设立条件的党支部，上级党委应当及时予以（ ）。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部书记负责主持党支部全面工作，督促党支部其他委员履行职责、发挥作用，抓好党支部委员会自身建设，向党支部委员会、党员大会和（ ）报告工作。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('发展党员工作应按照控制总量、优化结构、提高质量、（ ）的总要求进行。', '1', '中', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('发展党员工作要坚持党章规定的党员标准，始终将（ ）放在首位。', '1', '中', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('入党申请人需向工作、学习所在单位党组织提出入党申请；若无工作、学习单位或单位未建立党组织，应向（ ）党组织提出入党申请。', '1', '中', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('流动人员除可向单位所在地党组织或单位主管部门党组织提出入党申请外，还能向（ ）党组织提出入党申请。', '1', '中', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('确定入党积极分子，需采取党员推荐、（ ）等方式产生人选，由支部委员会（不设支部委员会的由支部大会）研究决定，并报上级党委备案。', '1', '中', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党组织对入党积极分子的教育方式，包含吸收入党积极分子听党课、参加党内有关活动、分配一定社会工作以及（ ）等。', '1', '中', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('入党介绍人一般由（ ）担任，也可由党组织指定。', '1', '中', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('受（ ）处分、尚未恢复党员权利的党员，不可作入党介绍人。', '1', '中', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党组织必须对发展对象进行（ ）。', '1', '中', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('未经（ ）的，除个别特殊情况外，不能发展入党。', '1', '中', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('支部委员会需对发展对象进行严格审查，经集体讨论认为合格后，报具有审批权限的（ ）预审。', '1', '中', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('召开讨论接收预备党员的支部大会，有表决权的到会人数必须超过应到会有表决权人数的（ ）。', '1', '中', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('支部大会讨论接收预备党员时，与会党员对发展对象能否入党充分讨论，并采取（ ）方式进行表决。', '1', '中', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部应当运用（ ）制度，对党员进行经常性的教育管理。', '1', '中', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('开展（ ）教育，帮助党员及时了解世情国情党情社情，统一思想认识。', '1', '中', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党组织会议表决可以根据讨论和决定事项的不同，采用（）（）（）（）等方式进行，赞成票超过应到会成员半数为通过。', '4', '中', '', '', '党员发展教育', '党建教育', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党的民主集中制原则要求“四个服从”，其中核心是__。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党的政治纪律是党最根本、最重要的纪律，遵守党的政治纪律是遵守__的基础。', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('“四个意识”是指政治意识、（）、核心意识、看齐意识。', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('“一岗双责”是指一个单位的领导干部应当对这个单位的（）和（）负双重责任。', '2', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('“四个自信”是指道路自信、理论自信、（）、文化自信。', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('公司宣传思想工作要形成“人人______、人人______、人人______、人人______”的品牌宣传工作大格局。', '1', '中', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('意识形态工作责任制的“三个纳入”是指纳入______、纳入领导班子考核、纳入干部考核。', '1', '中', '', '', '宣传工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('理论学习中心组学习以政治学习为根本，以深入学习______为主题主线。', '1', '中', '', '', '组织建设', '党建组织', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('习近平文化思想强调，要坚持以______为中心的创作导向。', '1', '中', '', '', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('中国建筑精神为______、______。', '1', '中', '', '', '企业文化', '企业管理', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('     是中国建筑的企业使命。', '1', '中', '', '', '企业文化', '企业管理', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('______是先锋文化的思想源泉。', '1', '中', '', '', '企业文化', '企业管理', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('新时代鲁班文化内涵的是______、______、______。', '1', '中', '', '', '企业文化', '企业管理', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('各项目 CI 工作执行小组组长由各单位（ ）担任。', '1', '中', '', '', 'CI工作', '其他', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('施工现场 CI 管理标准分为示范工程、创优工程（金奖、银奖）、（ ）三级。', '1', '中', '', '', 'CI工作', '其他', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('申报 “詹天佑奖” 的工程应达到（ ）工程 CI 标准。', '1', '中', '', '', 'CI工作', '其他', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('项目开工（ ）内项目部应编写《中建一局施工现场 CI 达标创优策划方案（模板）》。', '1', '中', '', '', 'CI工作', '其他', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('CI 工作应与项目施工组织设计同策划、同实施、同检查、同（ ）。', '1', '中', '', '', 'CI工作', '其他', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('门楼式大门外侧标识高______m。', '1', '中', '', '', 'CI工作', '其他', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('公司中英文全称与品牌标识进行组合时，必须严格遵守相关规范，不得违反或以任何方式更改或______。', '1', '中', '', '', 'CI工作', '其他', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('门禁闸机需贴编号牌，编号从______算起，为 “中建 1#”。', '1', '中', '', '', 'CI工作', '其他', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('CI 示范项目篇中发光标识包括门楼式大门发光标识、品牌布发光标识、塔吊发光标识和______发光标识。', '1', '中', '', '', 'CI工作', '其他', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('塔吊编号设置在塔吊______位置，编号为：“中建 X#”。', '1', '中', '', '', 'CI工作', '其他', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('施工现场应设封闭式垃圾站，施工垃圾、生活垃圾及有毒有害废弃物应____存放', '1', '中', '', '', 'CI工作', '其他', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('办公区临建楼体正中间上方设置 “中国建筑一局” 标识，左右两侧设置 “____”', '1', '中', '', '', 'CI工作', '其他', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('会议室主墙设置中国建筑 B 式组合 + 中建信条图牌，并设置落地旗，国旗位于____侧', '1', '中', '', '', 'CI工作', '其他', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('生活区山墙设置 “中国建筑” B 式组合标识，蓝腰带两侧体现（ ）标识。', '1', '中', '', '', 'CI工作', '其他', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('厨房工作人员操作时，必须穿戴好工作服、工作帽和________，并保持整洁。', '1', '中', '', '', 'CI工作', '其他', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('胸卡卡带挂绳印（ ）字样。', '1', '中', '', '', 'CI工作', '其他', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('安全教育体验馆栅栏设置 “中国建筑一局” 标识和 “（ ）” 标识。', '1', '中', '', '', 'CI工作', '其他', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('智慧建造指挥中心需与项目党支部五个价值创造点紧密融合，且建证标识、CI 标识运用（ ）。', '1', '中', '', '', 'CI工作', '其他', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('CI 示范项目承办活动中，中建集团宣传需（ ）次以上。', '1', '中', '', '', 'CI工作', '其他', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('工会会员代表大会的代表由会员（）选举产生，不得指定会员代表。', '1', '中', '', '', '工会工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('（）是职工行使民主管理权力的机构，是企业民主管理的基本形式。', '1', '中', '', '', '工会工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('职工代表大会的职权一般包括知情权、建议权、()、选举权、监督权等。', '1', '中', '', '', '工会工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('职工代表大会每届任期为三年至（）年。', '1', '中', '', '', '工会工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('（）是指工会代表职工与用人单位就涉及职工合法权益等事项进行平等商谈的行为。', '1', '中', '', '', '工会工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('新时期产业工人队伍建设改革方案中提出，要推动建设宏大的知识型、()、创新型劳动者大军。', '1', '中', '', '', '工会工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('新时期产业工人队伍建设改革方案中提出，要强化和创新产业工人队伍党建工作，加大在产业工人队伍中发展党员力度，把技术能手、青年专家、优秀工人吸收到（）中来。', '1', '中', '', '', '工会工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('《中建一局集团项目职工之家工作管理办法》中提到，进入现场需穿戴安全帽、三防鞋等（）用品。', '1', '中', '', '', '工会工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('《中建一局集团项目职工之家工作管理办法》规定，办公区、生活区的室内应保持整齐清洁，无（）、无污迹、无烟头、无积尘。', '1', '中', '', '', '工会工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('《中建一局集团项目职工之家工作管理办法》中提到，办公区、生活区的室外道路应平整，沟渠畅通，无（），无蚊蝇孳生地。', '1', '中', '', '', '工会工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('根据《中建一局集团项目职工之家工作管理办法》，厨房、餐厅、厕所等公共空间及设备应符合（）要求，每日清扫冲刷，保持清洁、定期消毒。', '1', '中', '', '', '工会工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('《中建一局集团项目职工之家工作管理办法》规定，人均住宿面积不低于（）平米，拥有独立的衣柜和写字桌。', '1', '中', '', '', '工会工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('《中建一局集团项目职工之家工作管理办法》规定，厨房菜、肉、米、油等食材应采购（ ）食品。', '1', '中', '', '', '工会工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('《中建一局集团项目职工之家工作管理办法》规定，为提高用餐效率和餐桌使用率，建议使用长方形餐桌，餐桌尺寸宽不小于（ ）公分。', '1', '中', '', '', '工会工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('根据《中建一局集团项目职工之家工作管理办法》，项目应配置医药箱，保证药品（）。', '1', '中', '', '', '工会工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('《中建一局集团项目职工之家工作管理办法》中提到，常规体检每年（）次。', '1', '中', '', '', '工会工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('《中建一局集团项目职工之家工作管理办法》中提到，企业发展必须明确坚定正确的（），职工之家建设也要始终做到党中央提倡什么就认真践行什么。', '1', '中', '', '', '工会工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('根据《中建一局集团项目职工之家工作管理办法》，项目职工之家建设要通过“建家”，体现人才培养、帮助与塑造，特别是（）人才队伍的建设和稳定工作。', '1', '中', '', '', '工会工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('《中建一局集团项目职工之家工作管理办法》规定，项目职工之家建设要通过“建家”，体现温馨和谐关爱，提高员工（）。', '1', '中', '', '', '工会工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('团员在三人以上的单位可以建立（ ）。', '1', '中', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('中国共产主义青年团是中国共产党的助手和（ ）。', '1', '中', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('团的建设必须坚持（ ）与群众性的统一。', '1', '中', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('团的根本任务是培养社会主义建设者和（ ）。', '1', '中', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('中国共产主义青年团自成立以来，始终牢记、忠实践行坚定不移（ ）、为党和人民奋斗的初心使命。', '1', '中', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('团支部是团组织开展工作的（ ）单元。', '1', '中', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('团支部设置一般以单位、区域、领域为主，以（ ）为主要方式。', '1', '中', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('团支部的调整或撤销需报（ ）批准。', '1', '中', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('团员的组织关系转接工作由（ ）负责。', '1', '中', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('《青年文明号活动管理办法》是为推动青年文明号工作与时俱进、改革创新，在共青团为党育人、（ ）中更好发挥作用、作出更大贡献而修订的办法。', '1', '中', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('开展“建证未来”青年精神素养专项实践，发挥“（ ）”等“青”字品牌作用。', '1', '中', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('开展“建证未来”青年精神素养专项实践，围绕集团改革发展和党的建设重点工作，将学习贯彻习近平总书记重要讲话精神的成效体现在青年（ ）的实效上。', '1', '中', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('“青马工程”的最终目标是培养一批政治坚定、德才兼备的（ ）', '1', '中', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('"青年大学习"行动要求各级党组织负责人每年至少上（ ）次党课。', '1', '中', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('团组织推优入党需坚持（ ）发展原则。', '1', '中', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO fill_in_blank_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('基层团组织规范化建设纳入（ ）考核体系。', '1', '中', '', '', '共青团工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('“三重一大”等重要事项在决策前必须经过本单位党委前置研究。', '1', '低', '', '正确', '企业战略与经营管理', '企业管理', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党风廉政建设方面，只有党委需要负主体责任，纪委不需要履行监督责任。', '1', '低', '', '错误', '党风廉政建设', '党建廉政', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('“两个一以贯之”原则中，坚持现代企业制度是可有可无的。', '1', '低', '', '错误', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('预备党员的权利同正式党员一样，有表决权、选举权和被选举权。', '1', '低', '', '错误', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党的基层组织对要求入党的积极分子进行教育和培养，做好经常性的发展党员工作，重视在生产、工作第一线和青年中发展党员。', '1', '低', '', '正确', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党组织讨论决定问题，必须执行少数服从多数的原则。', '1', '低', '', '正确', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党的纪律是党的各级组织和全体党员必须遵守的行为规则，是维护党的团结统一、完成党的任务的保证。', '1', '低', '', '正确', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党的基层委员会、总支部委员会、支部委员会的书记、副书记选举产生后，应报上级党组织批准。', '1', '低', '', '正确', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党组织对违犯党的纪律的党员，一律给予纪律处分。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党员在留党察看期间没有表决权、选举权和被选举权。', '1', '低', '', '正确', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党徽可以随意修改图案样式。（ ） ', '1', '低', '', '错误', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('开展党内政治生活，批评和自我批评可有可无。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('只要业务工作做好了，项目党支部建设可以放松。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党旗可以在任何商业活动中使用', '1', '低', '', '错误', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('项目党支部可以不设置党小组。', '1', '低', '', '正确', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('项目党支部发展党员，只要本人表现好，可不征求群众意见。（ ）', '1', '低', '', '错误', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('基层党组织选举时，有选举权
的到会人数超过应到会人数的三分之二，会议有效。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('选举人不能写选票的，可以由
本人委托非候选人按选举人的意志代写。', '1', '低', '', '正确', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('基层党组织选举采用记名投票
的方式。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党的基层组织选举工作，必须贯彻党的基本理论、基本路线、基本方略，遵循党章和党内有关规定，严格按照规定程序进行。', '1', '低', '', '正确', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('基层党组织选举时，候选人的名单应按姓氏笔画为序排列。', '1', '低', '', '正确', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('国有企业党支部（党总支）围绕生产经营开展工作，发挥战斗堡垒作用。', '1', '低', '', '正确', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('国有企业党员人数不足 50 人的，不能设立党的总支部委员会。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('国有企业中，党员人数较多或者党员工作地、居住地比较分散的党支部，按照便于组织开展活动原则，应当划分若干党小组。', '1', '低', '', '正确', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('国有企业党员教育管理中，可不组织流动党员参加组织生活。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('国有企业党组织设置和调整情况，应当每 2 年向上级党组织报告 1 次。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('国有企业党组织可以不组织党员过 “政治生日”。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('国有企业发展党员工作，要把技术骨干、青年职工和高知识群体作为重点发展对象。', '1', '低', '', '正确', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('国有企业党组织领导班子成员应当带头讲党课，党委（党组）书记每年至少讲 2 次党课。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('国有企业党组织应当建立健全党内激励关怀帮扶机制，对老党员、生活困难党员进行关怀帮扶。', '1', '低', '', '正确', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('国有企业中，项目、班组等基层单位，党员人数 3 人以上的，都应当成立党支部。', '1', '低', '', '正确', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部是党的基础组织，是党组织开展工作的基本单元，是党在社会基层组织中的战斗堡垒，是党的全部工作和战斗力的基础。', '1', '低', '', '正确', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('凡是有党员 3 人以上的，都应当成立党支部。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部党员人数一般不超过 30 人。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('临时党支部在特殊情况下可以发展党员、处分处置党员。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部的成立，只需基层单位自行决定即可，无需上级党组织批复。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部委员会由党支部党员大会选举产生，党支部书记、副书记必须由党支部委员会会议选举产生。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部委员会每届任期 2 年。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('有正式党员 5 人以上的党支部，应当设立党支部委员会。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部书记只负责党支部的日常事务，无需向党组织报告工作。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('“三会一课” 中的 “三会” 指的是党员大会、党支部委员会会议、党小组会。', '1', '低', '', '正确', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党员大会一般每半年召开 1 次。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部委员会会议根据需要随时召开，不用提前通知委员。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党小组会一般每季度召开 1 次。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党课必须由党支部书记讲授。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部每年必须召开 2 次组织生活会。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部一般每年开展 2 次民主评议党员。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部基本任务之一是将党支部建设成为实现党建工作与生产经营深度融合的战斗堡垒。', '1', '低', '', '正确', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部只需组织党员学习党的基本知识，无需学习习近平新时代中国特色社会主义思想。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部开展党员设岗定责活动是为了加强对党员的管理，而非发挥党员先锋模范作用。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部可以通过导师带徒、轮岗锻炼等方式加强青年人才的培养使用。', '1', '低', '', '正确', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部领导群团组织，但无需支持它们依照各自章程独立负责地开展工作。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('落实基层团组织 “推优入党” 不属于党支部的工作范畴。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部加强文化建设，只需深植先锋文化即可，无需关注鲁班文化。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部设置必须以单独组建为唯一方式。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('凡是有正式党员 2 人以上的，都应当成立党支部。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党员人数 50 人以上就必须设立党的总支部委员会。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('正式党员不足 3 人的单位，不能成立党支部。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('联合党支部覆盖单位没有数量限制。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('为执行某项任务临时组建的机构，只要有党员就可以成立临时党支部。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('临时党支部可以发展党员、处分处置党员。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('织委员负责安排组织生活会和民主评议党员等工作。', '1', '低', '', '正确', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('有正式党员 7 人的党支部，必须设立党支部委员会。', '1', '低', '', '正确', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('发展党员工作可以适当放宽政治标准，以增加党员数量。', '1', '低', '', '错误', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党的基层组织吸收先进分子入党是一项阶段性工作，无需常态化开展。', '1', '低', '', '错误', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('发展党员工作的总要求是增加数量、优化结构、提升质量、发挥作用。', '1', '低', '', '错误', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('总要求是控制总量、优化结构、提高质量、发挥作用。', '1', '低', '', '错误', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党组织收到入党申请书后，半年内派人同入党申请人谈话即可。', '1', '低', '', '错误', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('确定入党积极分子无需采取特定方式，可由支部书记直接指定。', '1', '低', '', '错误', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('入党积极分子可以由预备党员担任培养联系人。', '1', '低', '', '错误', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('对入党积极分子的考察只需党支部进行，基层党委无需参与。', '1', '低', '', '错误', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('入党积极分子经过半年培养教育和考察就可列为发展对象。', '1', '低', '', '错误', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('发展对象可以只有一名入党介绍人。', '1', '低', '', '错误', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('受党内警告处分的党员可以作入党介绍人。', '1', '低', '', '正确', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('预备党员的预备期为一年。', '1', '低', '', '正确', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('预备党员预备期满，预备党员本人应以书面形式向党组织提出转正申请。', '1', '低', '', '正确', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('预备党员转正的手续包含本人向党组织提出书面转正申请，党小组提出意见，党支部征求党员和群众意见，支部委员会审查，支部大会讨论、表决通过，报上级党委审批。', '1', '低', '', '正确', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('预备党员转正后，党支部应及时将其《中国共产党入党志愿书》、入党申请书、政治审查材料、转正申请书和培养教育考察材料，交党委存入本人人事档案。', '1', '低', '', '正确', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('发展党员工作禁止突击发展。', '1', '低', '', '正确', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('入党介绍人必须由党组织指定。', '1', '低', '', '正确', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('支部委员会应当对发展对象进行严格审查，需经集体讨论认为合格。', '1', '低', '', '正确', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('发展党员工作要坚持标准，既反对 “关门主义”，也不能放宽标准。', '1', '低', '', '正确', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党员教育管理工作只需遵循以人民为中心的原则即可。', '1', '低', '', '错误', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部应运用 “三会一课” 制度对党员进行经常性教育管理。', '1', '低', '', '正确', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部每年至少召开 1 次组织生活会。', '1', '低', '', '正确', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党支部一般每年开展 1 次民主评议党员。', '1', '低', '', '正确', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党员每年集中学习培训时间一般不少于 32 学时。', '1', '低', '', '正确', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('基层党组织书记和班子成员每年参加集中培训和集体学习时间不少于 32 学时。', '1', '低', '', '正确', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党员无需根据岗位职责学习业务知识，有理论知识就行。', '1', '低', '', '错误', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党组织利用信息化手段进行党员教育管理只是一种辅助方式，不必重视。', '1', '低', '', '错误', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('与党组织失去联系 3 个月以上的党员，就予以停止党籍。', '1', '低', '', '错误', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('停止党籍 2 年后确实无法取得联系的，按照自行脱党予以除名。', '1', '低', '', '正确', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党员组织关系是指党员对党的基层组织的隶属关系。', '1', '低', '', '正确', '党员发展教育', '党建教育', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('在党委会上传达学习集团党组、局党委有关会议精神，属于“第一议题”。', '1', '低', '', '错误', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('凡属公司党委职责范围内需要集体决定的事项，应当由党委会议集体讨论决定。党委会议一般每月召开1次，遇有重要情况可以随时召开。', '1', '低', '', '正确', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('对董事会授权执董会、总经理决策事项，党委会一般不再前置研究讨论。', '1', '低', '', '正确', '组织建设', '党建组织', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('廉政谈话主要包括经常性谈话（含提醒谈话）、任职谈话（含新提职谈话）、岗前谈话（含新入职谈话）、廉洁谈话、约谈、诫勉谈话等类型。', '1', '低', '', '错误', '党风廉政建设', '党建廉政', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党风廉政建设和反腐败工作领导小组每年至少召开1次会议，必要时邀请有关总部部门、二级公司负责人列席。', '1', '低', '', '错误', '党风廉政建设', '党建廉政', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('各级“一把手”每年听取1次所在领导班子其他成员履行“一岗双责”情况汇报。', '1', '低', '', '错误', '党风廉政建设', '党建廉政', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('重大工程类动态信息应早于媒体公开报道前上报。', '1', '低', '', '正确', '宣传工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('党的二十大报告指出，以人为本是立党为公、执政为民的本质要求。（  ）', '1', '低', '', '错误', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('《关于新形势下党内政治生活的若干准则》规定，必须把改革作为开展党内政治生活的首要任务。（  ）', '1', '低', '', '错误', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('《关于新形势下党内政治生活的若干准则》规定，每个党员要把维护党的集中统一，严格遵守党的纪律，作为自己言论和行动的准则。（ ）', '1', '低', '', '正确', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('《中国共产党纪律处分条例》仅适用于违犯党纪应当受到党纪追究的党员。（  ）', '1', '低', '', '错误', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('《中国共产党纪律处分条例》规定，主动交代，是指涉嫌违纪的党员在组织初核前向有关组织交代自己的问题，或者在初核和立案审查其问题期间交代组织未掌握的问题。（  ）', '1', '低', '', '正确', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('《中国共产党党内监督条例》规定，党委（党组）在党内监督中负主体责任，书记是第一责任人，党委常委会委员（党组成员）和党委委员在职责范围内履行监督职责。（   ）', '1', '低', '', '正确', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('《中国共产党党内监督条例》规定，发现领导干部有思想、作风、纪律等方面苗头性、倾向性问题的，有关党组织负责人应当及时对其诫勉谈话。（  ）', '1', '低', '', '错误', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('《关于加强对“一把手”和领导班子监督的意见》规定，落实纪检机关、组织部门负责人同下级“一把手”谈话制度，发现一般性问题及时向本人提出，发现严重违纪违法问题向同级党委主要负责人报告。（  ）', '1', '低', '', '正确', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('《中国共产党问责条例》规定，问责对象是党组织、党的领导干部，重点是党委（党组）、党的工作机关及其领导成员，纪委、纪委派驻（派出）机构及其领导成员。（  ）', '1', '低', '', '错误', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('《中国共产党问责条例》规定，对党组织问责的，可以不对该党组织中负有责任的领导班子成员进行问责。（  ）', '1', '低', '', '错误', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('根据《中国共产党组织处理规定（试行）》，组织处理不能和党纪政务处分合并使用。（ ）', '1', '低', '', '错误', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('根据《国有企业领导人员廉洁从业若干规定》，未经企业领导班子集体研究，国有企业领导人员不能擅自决定捐赠、赞助事项。（  ）', '1', '低', '', '正确', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('根据《国有企业领导人员廉洁从业若干规定》，国有企业领导人员即使离职后也不得接受管理和服务对象提供的物质性利益。（   ）', '1', '低', '', '正确', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('根据《国有企业领导人员廉洁从业若干规定》，国有企业领导人员经批准可以在其他企业中兼职，但不能擅自领取薪酬。（  ）', '1', '低', '', '正确', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('根据《国有企业领导人员廉洁从业若干规定》，国有企业领导人员在企业拖欠职工工资期间，不得购买小汽车、添置高档办公设备，但可以装修办公室。（  ）', '1', '低', '', '错误', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('根据《国有企业领导人员廉洁从业若干规定》，国有企业领导人员因违反《国有企业领导人员廉洁从业若干规定》获取的不正当经济利益，给国有企业造成经济损失的，应当依据国家或者企业有关规定承担经济赔偿责任。（  ）', '1', '低', '', '正确', '党的基本制度理论及相关要求', '党建理论', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('严格执行全面从严治党主体责任制度，落实“一把手”第一责任人职责。（  ）', '1', '低', '', '正确', '党风廉政建设', '党建廉政', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('宣传思想文化工作事关党的前途命运，事关国家长治久安，事关民族凝聚力和向心力，是一项极端重要的工作', '1', '低', '', '正确', '宣传工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('项目员工可以私自开设自有媒体平台，无需报备。（）', '1', '低', '', '错误', '宣传工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('外部新闻稿件内容可以涉及机密和不宜公开的信息。', '1', '低', '', '错误', '宣传工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('公司各级党组织书记是本单位宣传、品牌传播工作的第一责任人。', '1', '低', '', '正确', '宣传工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('在媒体宣传中，内容越冗长越能传递完整信息', '1', '低', '', '错误', '宣传工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('企业宣传物料中可使用未经授权的图片素材。', '1', '低', '', '错误', '宣传工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('项目“一句话标签”应每年更换一次，以保持新鲜感。', '1', '低', '', '错误', '宣传工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('短视频宣传中，背景音乐无需考虑版权问题。', '1', '低', '', '错误', '宣传工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('图片分辨率越低，加载速度越快，更适合移动端宣传。', '1', '低', '', '错误', '宣传工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('宣传图片中的企业Logo可以根据需要调换大小，但应保持比例一致', '1', '低', '', '正确', '宣传工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('项目部接受地方媒体采访，可以不向企业文化部提前报备。', '1', '低', '', '错误', '舆情工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('意识形态工作责任制仅适用于公司总部，不适用于项目部。', '1', '低', '', '错误', '宣传工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('《中建信条（2024版）》和《十典九章（2024版）》都是中国建筑的文化手册。', '1', '低', '', '正确', '企业文化', '企业管理', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('项目发生安全生产事故，只会取消 CI 创优项目资格，不会影响 CI 示范项目资格。', '1', '低', '', '错误', 'CI工作', '其他', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('无门楼式大门在任何情况下都不可变形使用。', '1', '低', '', '错误', 'CI工作', '其他', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('中建一局公司中文简称与品牌标识进行组合时，有严格的规范要求。', '1', '低', '', '正确', 'CI工作', '其他', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('施工图牌必须设置于大门外侧。', '1', '低', '', '错误', 'CI工作', '其他', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('茶水亭可以在塔吊回转半径内设置。', '1', '低', '', '错误', 'CI工作', '其他', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('会议室严禁悬挂工作制度牌、流程图等', '1', '低', '', '正确', 'CI工作', '其他', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('项目员工岗位职责内容有统一标准。', '1', '低', '', '错误', 'CI工作', '其他', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('业主、监理单位的办公室门牌可以出现标识图形。', '1', '低', '', '错误', 'CI工作', '其他', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('分包管理人员安全帽编号都是 B - XXX。', '1', '低', '', '错误', 'CI工作', '其他', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('创优项目内侧品牌墙左侧是中建信条，右侧是本项目效果图。', '1', '低', '', '错误', 'CI工作', '其他', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('道旗主要应用于项目施工日常，而非仅在观摩、迎检等品牌活动。', '1', '低', '', '错误', 'CI工作', '其他', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('样板展示区大门标语有固定样式，不得更改。', '1', '低', '', '正确', 'CI工作', '其他', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('未经报批同意，干部职工不能擅自以工作职务或单位名义接受媒体采访（包括境内外媒体的电话采访、书面采访、面对面采访、参加访谈等任何形式的采访）', '1', '低', '', '正确', '舆情工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('接到媒体采访需求时，了解媒体的基本情况、核实记者的身份职务，转交宣传部门办理', '1', '低', '', '正确', '舆情工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('行政部门为媒体采访管理部门，所有媒体采访由行政部门统筹安排，按照“采前报批、准备口径、组织采访、联审稿件、发布对接、传播评估”的流程组织实施', '1', '低', '', '错误', '舆情工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('各单位接到内参采访需求时，统一由集团宣传部门报涉及的业务分管领导、宣传工作分管领导、党组书记审批 同意后组织落实', '1', '低', '', '错误', '舆情工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('做好采访组织协调，为媒体采访提供支持保障。品牌宣传部全程参加采访，做好采访记录，在媒体和受访 人员同意的情况下，留存采访录音、影像资料。', '1', '低', '', '错误', '舆情工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('事先根据真实情况、媒体采访提纲准备口径方案，不要在没有准备的条件下接受采访，同时保持内外部信息一致性，必要时提前进行模拟演练', '1', '低', '', '正确', '舆情工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('子企业召开新闻发布会或记者见面会，要提前报请局批准并接受指导；项目部召开新闻发布会或记者见面会，要提前报请局品牌管理部批准并接受指导', '1', '低', '', '错误', '舆情工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('项目部抓好项目管理人员和分包队伍、保安的新闻危机管理教育培训，提高防范新闻危机的应对技能，组织预案演练', '1', '低', '', '错误', '舆情工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('有人员在新闻发布会过程中进行抗议、闹场，要遵循快速处理、适度包容、柔和处置的原则，切忌简单粗暴的工作方式，防止因处理不当引发次生舆情', '1', '低', '', '正确', '舆情工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('同时接待多家媒体时，可以根据媒体级别影响力、记者职位高低进行区别对待。', '1', '低', '', '错误', '舆情工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('项目部要抓好项目管理人员和分包队伍、门卫的新闻危机管理教育培训，提高防范新闻危机的应对技能，组织预案演练。', '1', '低', '', '正确', '舆情工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('接受记者采访要统一口径、实事求是，不编造谎言。不要说无可奉告，对于暂时不了解的问题，也不要仅说“不知道”。即使信息要保密，也必须给予合理解释。', '1', '低', '', '正确', '舆情工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('工会是职工自愿结合的工人阶级的群众组织，其基本职责是维护职工合法权益。', '1', '低', '', '正确', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('企业工会委员会的任期为3年或5年，具体任期由会员大会或会员代表大会决定。', '1', '低', '', '正确', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('职工代表大会是企业民主管理的基本形式，职工代表由企业工会直接任命。', '1', '低', '', '错误', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('工会经费的来源之一是企业按职工工资总额的2%向工会拨缴的经费。', '1', '低', '', '正确', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('工会会员退会后，其会员证可以继续保留使用。', '1', '低', '', '错误', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('工会组织职工开展劳动竞赛等活动属于工会的经济职能范畴。', '1', '低', '', '正确', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('工会经费审查委员会的职责是对工会经费收支和资产管理情况进行审查监督。', '1', '低', '', '正确', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('工会组织职工开展文体活动时，可以使用工会经费购买必要的器材和设备。', '1', '低', '', '正确', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('工会组织职工开展技能培训活动属于工会的教育职能范畴。', '1', '低', '', '正确', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('工会组织职工开展文体活动时，不得使用工会经费。', '1', '低', '', '错误', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('工会组织职工开展劳动竞赛等活动时，应注重活动的实效性和职工参与度。', '1', '低', '', '正确', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('工会组织职工开展合理化建议活动时，应鼓励职工提出具有创新性和可操作性的建议。', '1', '低', '', '正确', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('工会会员在保留会籍期间，仍可参与工会组织的文体活动。', '1', '低', '', '正确', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('职工代表大会是职工行使民主管理权力的机构，是企业民主管理的基本形式。', '1', '低', '', '正确', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('企业工会在企业民主管理中仅负责组织职工参与企业管理，不承担其他职责。', '1', '低', '', '错误', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('职工代表大会的代表由工人、技术人员、管理人员、企业领导人员和其他方面的职工组成。', '1', '低', '', '正确', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('职工代表在任期内调离本企业或退休时，代表资格自行终止。', '1', '低', '', '正确', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('职工代表提案只能在职工代表大会期间提出。', '1', '低', '', '错误', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('集体合同由工会代表职工与企业签订，具有法律效力。', '1', '低', '', '正确', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('厂务公开的责任主体是企业的主要负责人，包括党组织负责人、企业法定代表人、工会负责人。', '1', '低', '', '正确', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('职工代表提案必须一事一案，不能一案多事。', '1', '低', '', '正确', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('职工代表大会的主席团成员中，工人、技术人员、管理人员的比例不少于50%。', '1', '低', '', '正确', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('工会经费的使用应遵循服务职工、廉洁办会、程序规范和办事公开的原则。', '1', '低', '', '正确', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('工会固定资产是指单位价值在1000元以上、使用年限在一年以上的资产。', '1', '低', '', '错误', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('工会经费可以用于发放现金形式的节日慰问品。', '1', '低', '', '错误', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('工会经费可以用于购买劳保用品。', '1', '低', '', '错误', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('工会经费可以用于组织职工开展红色之旅活动。', '1', '低', '', '错误', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('工会经费可以用于支付职工体检费用。', '1', '低', '', '错误', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('工会经费可以用于购买交通意外险。', '1', '低', '', '正确', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('工会经费可以用于支付职工培训费用。', '1', '低', '', '正确', '工会工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('团费的交纳办法由公司团委自行决定', '1', '低', '', '错误', '共青团工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('团支部团员人数经上级批准可超过50人', '1', '低', '', '正确', '共青团工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('团的基层组织设置应完全与党组织设置一致', '1', '低', '', '错误', '共青团工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('团章是共青团一切工作和活动的基本准则', '1', '低', '', '正确', '共青团工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('团费缴纳标准由地方团委决定', '1', '低', '', '错误', '共青团工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('共青团员发挥模范带头作用的总体要求的核心指导思想是马克思列宁主义、毛泽东思想、邓小平理论和“三个代表”重要思想', '1', '低', '', '正确', '共青团工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('落实“三会两制一课”是共青团保持和增强政治性、先进性、群众性的必然要求', '1', '低', '', '正确', '共青团工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('基层团组织考核评估的主要依据是“智慧团建”系统数据', '1', '低', '', '正确', '共青团工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('团组织可先于党组织在新兴领域建立', '1', '低', '', '正确', '共青团工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('青年突击队活动属于"青"字号品牌项目', '1', '低', '', '正确', '共青团工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('青年突击队实行队长负责制，在队长的领导下开展工作。', '1', '低', '', '正确', '共青团工作', '群团工作', NOW());
INSERT INTO true_false_questions (question_stem, score, difficulty, analysis, answer, primary_tag, secondary_tag, created_at)
VALUES ('基层团组织规范化建设需与党建统筹推进', '1', '低', '', '正确', '共青团工作', '群团工作', NOW());