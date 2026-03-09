# AIPI 自动评分系统

这是一个基于大语言模型（LLM）的智能自动评分系统，能够根据参考答案自动对学生的问答题进行多维度的评分和反馈。

## 1. 系统架构与表结构设计

系统对接远程 MySQL 数据库，包含以下数据表：

### tb_essays

简答题表：存储简答题信息

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `question_text` | text | NO |  | NULL | 题目内容 |
| `reference_answer` | text | NO |  | NULL | 参考答案，用于AI批改或人工参考 |
| `scoring_rule` | text | YES |  | NULL | 评分规则：用于存储简答题的评分标准和规则 |
| `score` | int | NO |  | 20 | 题目分值，默认20分 |
| `created_at` | datetime | YES |  | CURRENT_TIMESTAMP | 创建时间，默认为当前时间 |
| `updated_at` | datetime | YES |  | CURRENT_TIMESTAMP | 更新时间，默认当前时间，更新时自动更新 |
| `rubric` | json | YES |  | NULL | 评分标准 |
| `is_rubric_parsed` | tinyint(1) | YES |  | 0 | 是否已解析评分要点 |


### answers

答题结果表：存储用户答题记录

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `user_id` | int | NO | MUL | NULL | 外键，关联到users表的id字段，当用户被删除时，相关答题记录也会被级联删除 |
| `question_id` | int | NO | MUL | NULL | 题目ID，关联到题库中的题目 |
| `bank_id` | int | NO | MUL | 3 | 题库ID，默认为3 |
| `user_answer` | text | NO |  | NULL | 用户的答题内容，文本类型，支持较长的回答 |
| `score` | int | NO |  | NULL | 答题得分，整数类型 |
| `analysis_status` | tinyint | NO | MUL | 0 | 分析状态：0-待分析，1-分析中，2-分析完成，3-分析失败 |
| `analysis_id` | int | YES | MUL | NULL | 分析结果ID，关联到answer_analyses表的id字段，当分析结果被删除时，该字段设为NULL |
| `submitted_at` | datetime | YES | MUL | CURRENT_TIMESTAMP | 答题提交时间，默认为当前时间 |
| `ai_content_score` | decimal(5,1) | YES |  | NULL | 内容得分 |
| `ai_quality_score` | decimal(5,1) | YES |  | NULL | 质量得分 |
| `ai_topic_score` | decimal(5,1) | YES |  | NULL | 主题得分 |
| `ai_final_score` | int | YES |  | NULL | 最终得分 |
| `ai_report` | text | YES |  | NULL | 评分报告 |
| `ai_details` | json | YES |  | NULL | 评分详情 |


### 其他业务表

### answer_analyses

答题分析结果表：存储AI对用户答题的分析结果

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `answer_id` | int | NO | MUL | NULL | 外键，关联到answers表的id字段，当答题记录被删除时，相关分析结果也会被级联删除 |
| `analysis_content` | text | NO |  | NULL | AI分析结果内容，文本类型，支持较长的分析报告 |
| `analyzed_by` | varchar(50) | NO |  | NULL | 分析人员，记录是谁触发了分析 |
| `analyzed_at` | datetime | YES | MUL | CURRENT_TIMESTAMP | 分析时间，默认为当前时间 |


### assessment_batches

考核批次表：存储考核批次信息

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `batch_name` | varchar(100) | NO | MUL | NULL | 批次名称 |
| `assessment_type` | varchar(20) | NO | MUL | NULL | 考核类型：月度/季度/年度/专项 |
| `title` | varchar(200) | NO |  | NULL | 考核主题（对应题库名称） |
| `start_date` | datetime | NO |  | NULL | 开始时间 |
| `end_date` | datetime | NO |  | NULL | 结束时间 |
| `bank_id_range` | varchar(255) | NO |  |  | 题库ID范围，如 "1-5" 或 "1,3,5" |
| `is_current` | tinyint(1) | NO | MUL | 0 | 是否当前考核，1-是，0-否 |
| `status` | enum('draft','active','completed') | NO | MUL | draft | 状态：草稿/进行中/已完成 |
| `created_at` | datetime | YES |  | CURRENT_TIMESTAMP | 创建时间，默认为当前时间 |
| `updated_at` | datetime | YES |  | CURRENT_TIMESTAMP | 更新时间，默认当前时间，更新时自动更新 |


### choice_answers

选择判断题回答表：用于存放单选题、多选题和判断题的回答内容

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `user_id` | int | NO | MUL | NULL | 外键，关联到users表的id字段，当用户被删除时，相关答题记录也会被级联删除 |
| `question_id` | int | NO | MUL | NULL | 题目ID，关联到题库中的题目 |
| `bank_id` | int | NO | MUL | 3 | 题库ID，默认为3 |
| `user_answer` | varchar(255) | NO |  | NULL | 用户的答题内容，字符串类型，适合存储选择题答案 |
| `score` | int | NO |  | NULL | 答题得分，整数类型 |
| `is_correct` | tinyint | NO |  | 0 | 是否正确：0-错误，1-正确 |
| `question_type` | tinyint | NO | MUL | NULL | 题目类型：1-单选题，2-多选题，3-判断题 |
| `submitted_at` | datetime | YES | MUL | CURRENT_TIMESTAMP | 答题提交时间，默认为当前时间 |


### exam_candidates

待考人员表：存储待考人员信息

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `batch_id` | int | NO | MUL | NULL | 外键，关联到考核批次表的id字段 |
| `group_id` | int | YES | MUL | NULL | 外键，关联到考核群组表的id字段，NULL表示直接添加的人员 |
| `phone` | varchar(20) | NO | MUL | NULL | 手机号 |
| `user_id` | int | NO | MUL | 0 | 用户ID，关联到users表 |
| `assigned_bank_ids` | varchar(255) | NO |  |  | 分配给该考生的具体题库ID |
| `name` | varchar(50) | NO |  | NULL | 姓名 |
| `status` | enum('pending','completed','absent') | NO | MUL | pending | 状态：待考/已完成/缺席 |
| `score` | int | YES |  | NULL | 得分，NULL表示未考试或未批改 |
| `completed_at` | datetime | YES |  | NULL | 完成时间，NULL表示未完成 |


### exam_group_users

群组用户表：存储群组与用户的关联关系

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `group_id` | int | NO | MUL | NULL | 外键，关联到考核群组表的id字段 |
| `user_id` | int | NO | MUL | NULL | 外键，关联到用户表的id字段 |
| `phone` | varchar(20) | NO | MUL | NULL | 用户手机号 |
| `name` | varchar(50) | NO |  | NULL | 用户姓名 |


### exam_groups

考核群组表：存储考核群组信息

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `group_name` | varchar(100) | NO | MUL | NULL | 群组名称 |
| `description` | text | YES |  | NULL | 群组描述 |
| `created_by` | varchar(50) | NO | MUL | NULL | 创建人 |
| `created_at` | datetime | YES |  | CURRENT_TIMESTAMP | 创建时间，默认为当前时间 |
| `updated_at` | datetime | YES |  | CURRENT_TIMESTAMP | 更新时间，默认当前时间，更新时自动更新 |


### exam_records

考试相关记录

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL |  |
| `user_id` | int | NO | MUL | NULL |  |
| `phone` | varchar(20) | NO | MUL | NULL |  |
| `bank_id` | int | NO | MUL | NULL |  |
| `bank_id_range` | varchar(255) | YES |  | NULL |  |
| `exam_candidate_id` | int | YES | MUL | NULL |  |
| `batch_id` | int | YES | MUL | NULL |  |
| `title` | varchar(255) | YES |  | NULL |  |
| `info` | text | YES |  | NULL |  |
| `bankname` | varchar(255) | YES |  | NULL |  |
| `bankstatus` | enum('pending','completed','absent') | YES |  | pending | 状态：待考/已完成/缺席 |
| `start_time` | date | YES |  | NULL |  |
| `end_time` | date | YES |  | NULL |  |
| `correct_rate` | decimal(5,2) | YES |  | NULL |  |
| `answered_count` | int | YES |  | NULL |  |
| `unanswered_count` | int | YES |  | NULL |  |
| `incorrect_count` | int | YES |  | NULL |  |
| `final_score` | decimal(6,2) | YES |  | NULL |  |
| `study_suggestion` | text | YES |  | NULL |  |
| `record_type` | enum('exam','history','score','analysis') | NO | MUL | NULL | 记录类型：考试/历史/得分/分析 |
| `created_at` | timestamp | YES |  | CURRENT_TIMESTAMP |  |
| `updated_at` | timestamp | YES |  | CURRENT_TIMESTAMP |  |


### fill_in_blank_questions

填空题表

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID |
| `question_stem` | text | NO |  | NULL | 试题题干 |
| `score` | tinyint | NO |  | 1 | 分数 |
| `difficulty` | varchar(10) | NO | MUL | 低 | 难易度：低/中/高 |
| `analysis` | text | YES |  | NULL | 试题解析 |
| `answer` | text | NO |  | NULL | 答案（可能多个答案，用分号分隔） |
| `primary_tag` | varchar(100) | YES | MUL | NULL | 一级标签 |
| `secondary_tag` | varchar(100) | YES | MUL | NULL | 二级标签 多个标签用逗号分隔，如：党员,干部,积极分子 |
| `created_at` | timestamp | NO |  | CURRENT_TIMESTAMP | 创建时间 |
| `updated_at` | timestamp | YES |  | NULL | 更新时间 |


### import_history

导入历史表：存储员工信息导入历史

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `file_name` | varchar(100) | NO | MUL | NULL | 导入文件名 |
| `file_path` | varchar(255) | NO |  | NULL | 文件存储路径 |
| `imported_count` | int | NO |  | 0 | 成功导入数量 |
| `failed_count` | int | NO |  | 0 | 导入失败数量 |
| `status` | enum('success','failed','partial') | NO | MUL | success | 导入状态：成功/失败/部分成功 |
| `created_by` | varchar(50) | NO |  | NULL | 导入人 |
| `created_at` | datetime | YES | MUL | CURRENT_TIMESTAMP | 创建时间，默认为当前时间 |


### knowledge_base

知识库表：存储知识库信息

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `title` | varchar(200) | NO | MUL | NULL | 标题 |
| `content` | text | NO |  | NULL | 内容 |
| `category` | varchar(100) | NO | MUL | NULL | 分类 |
| `tags` | text | YES |  | NULL | 标签，多个标签用逗号分隔 |
| `file_url` | varchar(255) | YES |  | NULL | 文件URL，上传的文件路径 |
| `created_at` | datetime | YES | MUL | CURRENT_TIMESTAMP | 创建时间，默认为当前时间 |
| `updated_at` | datetime | YES |  | CURRENT_TIMESTAMP | 更新时间，默认当前时间，更新时自动更新 |


### models

大模型管理表：存储大模型配置信息

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `model_name` | varchar(100) | NO | MUL | NULL | 模型名称 |
| `api_url` | varchar(255) | NO |  | NULL | API地址 |
| `api_key` | varchar(255) | NO |  | NULL | API密钥 |
| `description` | text | YES |  | NULL | 模型描述 |
| `is_active` | tinyint(1) | NO | MUL | 1 | 是否启用，1-启用，0-禁用 |
| `created_at` | datetime | YES |  | CURRENT_TIMESTAMP | 创建时间，默认为当前时间 |
| `updated_at` | datetime | YES |  | CURRENT_TIMESTAMP | 更新时间，默认当前时间，更新时自动更新 |


### multiple_choice_questions

多选题表

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID |
| `question_stem` | text | NO |  | NULL | 试题题干 |
| `question_type` | varchar(20) | NO | MUL | NULL | 试题类型：多选/不定项 |
| `score` | tinyint | NO |  | 1 | 分数 |
| `difficulty` | varchar(10) | NO | MUL | 低 | 难易度：低/中/高 |
| `analysis` | text | YES |  | NULL | 试题解析 |
| `answer` | varchar(50) | NO |  | NULL | 答案（如：ABC/ABCD） |
| `option_a` | text | NO |  | NULL | 选项A |
| `option_b` | text | NO |  | NULL | 选项B |
| `option_c` | text | NO |  | NULL | 选项C |
| `option_d` | text | NO |  | NULL | 选项D |
| `option_e` | text | NO |  | NULL | 选项E |
| `option_f` | text | NO |  | NULL | 选项F |
| `option_g` | text | NO |  | NULL | 选项G |
| `option_h` | text | NO |  | NULL | 选项H |
| `option_i` | text | NO |  | NULL | 选项I |
| `option_j` | text | NO |  | NULL | 选项J |
| `primary_tag` | varchar(100) | YES | MUL | NULL | 一级标签 |
| `secondary_tag` | varchar(100) | YES | MUL | NULL | 二级标签 多个标签用逗号分隔，如：党员,干部,积极分子 |
| `created_at` | timestamp | NO |  | CURRENT_TIMESTAMP | 创建时间 |
| `updated_at` | timestamp | YES |  | NULL | 更新时间 |


### single_choice_questions

单选题表

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID |
| `question_stem` | text | NO |  | NULL | 试题题干 |
| `score` | tinyint | NO |  | 1 | 分数 |
| `difficulty` | varchar(10) | NO | MUL | 低 | 难易度：低/中/高 |
| `analysis` | text | YES |  | NULL | 试题解析 |
| `answer` | varchar(10) | NO |  | NULL | 答案（A/B/C/D等） |
| `option_a` | text | NO |  | NULL | 选项A |
| `option_b` | text | NO |  | NULL | 选项B |
| `option_c` | text | NO |  | NULL | 选项C |
| `option_d` | text | NO |  | NULL | 选项D |
| `option_e` | text | NO |  | NULL | 选项E |
| `option_f` | text | NO |  | NULL | 选项F |
| `option_g` | text | NO |  | NULL | 选项G |
| `option_h` | text | NO |  | NULL | 选项H |
| `option_i` | text | NO |  | NULL | 选项I |
| `option_j` | text | NO |  | NULL | 选项J |
| `primary_tag` | varchar(100) | YES | MUL | NULL | 一级标签 |
| `secondary_tag` | varchar(100) | YES | MUL | NULL | 二级标签 多个标签用逗号分隔，如：党员,干部,积极分子 |
| `created_at` | timestamp | NO |  | CURRENT_TIMESTAMP | 创建时间 |
| `updated_at` | timestamp | YES |  | NULL | 更新时间 |


### tb_bank_questions

题库与题目对应关系表：存储题库包含的题目

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `bank_id` | int | NO | MUL | NULL | 外键，关联到题库表的id字段，当题库被删除时，相关题目关联也会被级联删除 |
| `question_id` | int | NO |  | NULL | 题目ID，对应不同题型表的id |
| `question_type` | tinyint | NO | MUL | NULL | 题目类型：1-单选题，2-多选题，3-判断题，4-简答题 |
| `sort_order` | int | YES |  | 0 | 题目在题库中的排序序号 |
| `created_at` | datetime | YES |  | CURRENT_TIMESTAMP | 创建时间，默认为当前时间 |


### tb_banks

题库信息表：存储题库基本信息

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `bank_name` | varchar(100) | NO | MUL | NULL | 题库名称 |
| `description` | text | YES |  | NULL | 题库描述 |
| `created_at` | datetime | YES |  | CURRENT_TIMESTAMP | 创建时间，默认为当前时间 |
| `updated_at` | datetime | YES |  | CURRENT_TIMESTAMP | 更新时间，默认当前时间，更新时自动更新 |


### tb_judges

判断题表：存储判断题信息

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `question_text` | text | NO |  | NULL | 题目内容 |
| `correct_answer` | tinyint | NO |  | NULL | 正确答案：1-正确，0-错误 |
| `explanation` | text | YES |  | NULL | 答案解析 |
| `score` | int | NO |  | 5 | 题目分值，默认5分 |
| `created_at` | datetime | YES |  | CURRENT_TIMESTAMP | 创建时间，默认为当前时间 |
| `updated_at` | datetime | YES |  | CURRENT_TIMESTAMP | 更新时间，默认当前时间，更新时自动更新 |


### tb_multiple_choices

多选题表：存储多选题信息

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `question_text` | text | NO |  | NULL | 题目内容 |
| `option_a` | text | NO |  | NULL | 选项A |
| `option_b` | text | NO |  | NULL | 选项B |
| `option_c` | text | NO |  | NULL | 选项C |
| `option_d` | text | NO |  | NULL | 选项D |
| `option_e` | text | NO |  | NULL | 选项E |
| `correct_answer` | varchar(20) | NO | MUL | NULL | 正确答案：多个选项用逗号分隔，如"A,B,D" |
| `explanation` | text | YES |  | NULL | 答案解析 |
| `score` | int | NO |  | 10 | 题目分值，默认10分 |
| `created_at` | datetime | YES |  | CURRENT_TIMESTAMP | 创建时间，默认为当前时间 |
| `updated_at` | datetime | YES |  | CURRENT_TIMESTAMP | 更新时间，默认当前时间，更新时自动更新 |


### tb_single_choices

Single Choice Question

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `question_text` | text | NO |  | NULL | 题目内容 |
| `option_a` | text | NO |  | NULL | 选项A |
| `option_b` | text | NO |  | NULL | 选项B |
| `option_c` | text | NO |  | NULL | 选项C |
| `option_d` | text | NO |  | NULL | 选项D |
| `correct_answer` | char(1) | NO |  | NULL | 正确答案：A/B/C/D |
| `explanation` | text | YES |  | NULL | 答案解析 |
| `score` | int | NO |  | 10 | 题目分值，默认10分 |
| `created_at` | datetime | YES |  | CURRENT_TIMESTAMP | 创建时间，默认为当前时间 |
| `updated_at` | datetime | YES |  | CURRENT_TIMESTAMP | 更新时间，默认当前时间，更新时自动更新 |


### tb_tags

Question Tags

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | Primary Key |
| `question_id` | int | NO |  | NULL | Question ID |
| `question_tag` | varchar(255) | NO |  | NULL | Question Tag |
| `tag_score` | float | NO |  | NULL | Tag Score |
| `create_time` | datetime | YES |  | NULL | Create Time |


### true_false_questions

判断题表

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID |
| `question_stem` | text | NO |  | NULL | 试题题干 |
| `score` | tinyint | NO |  | 1 | 分数 |
| `difficulty` | varchar(10) | NO | MUL | 低 | 难易度：低/中/高 |
| `analysis` | text | YES |  | NULL | 试题解析 |
| `answer` | varchar(10) | NO |  | NULL | 答案（对/错 或 √/×） |
| `primary_tag` | varchar(100) | YES | MUL | NULL | 一级标签 |
| `secondary_tag` | varchar(100) | YES | MUL | NULL | 二级标签 多个标签用逗号分隔，如：党员,干部,积极分子 |
| `created_at` | timestamp | NO |  | CURRENT_TIMESTAMP | 创建时间 |
| `updated_at` | timestamp | YES |  | NULL | 更新时间 |


### user_file

用户文件表：存储用户上传的文件记录

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `user_id` | int | NO | MUL | NULL | 外键，关联到用户表的id字段 |
| `fileName` | varchar(100) | NO | MUL | NULL | 文件名，包含文件扩展名 |
| `filePath` | varchar(255) | NO |  | NULL | 文件存储路径，服务器本地路径 |
| `fileUrl` | varchar(255) | NO |  | NULL | 文件访问URL，前端可直接访问的URL |
| `fileSize` | int | NO |  | NULL | 文件大小，单位为字节 |
| `fileType` | varchar(50) | NO | MUL | NULL | 文件类型，如image/jpeg |
| `createdAt` | datetime | YES | MUL | CURRENT_TIMESTAMP | 创建时间，默认为当前时间 |


### user_wechat

微信用户表：存储微信一键登录用户信息

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `memberOpenid` | varchar(100) | NO | UNI | NULL | 微信用户唯一标识，来自微信API |
| `memberPhone` | varchar(20) | YES | MUL | NULL | 用户手机号，来自微信手机号授权 |
| `memberNickname` | varchar(50) | YES |  | NULL | 用户昵称，来自微信用户信息 |
| `memberAvatar` | varchar(255) | YES |  | NULL | 用户头像URL，来自微信用户信息 |
| `memberIdstate` | tinyint | NO |  | 1 | 实名状态：0-已实名，1-未实名 |
| `memberOnly` | varchar(255) | YES | MUL | NULL | 用户token，用于身份验证，等同于传统token |
| `memberProtocolstate` | tinyint | NO |  | 1 | 协议状态：0-已同意，1-未同意 |
| `sessionKey` | varchar(100) | YES |  | NULL | 微信会话密钥，用于解密敏感信息 |
| `unionid` | varchar(100) | YES |  | NULL | 用户在开放平台的唯一标识符（可选） |
| `createdAt` | datetime | YES |  | CURRENT_TIMESTAMP | 创建时间，默认为当前时间 |
| `updatedAt` | datetime | YES |  | CURRENT_TIMESTAMP | 更新时间，默认为当前时间，自动更新 |


### users

用户表：存储系统用户信息

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `username` | varchar(50) | NO | UNI | NULL | 用户名，用于登录，唯一不可重复 |
| `password` | varchar(255) | NO |  | NULL | 密码，使用scrypt加密存储 |
| `phone` | varchar(20) | NO | UNI | NULL | 电话号码，用于用户联系，唯一不可重复 |
| `name` | varchar(50) | NO |  | NULL | 姓名，用户真实姓名 |
| `unit` | varchar(100) | YES |  | NULL | 单位，用户所属单位 |
| `position` | varchar(50) | YES |  | NULL | 职务，用户在单位中的职务 |
| `tags` | text | YES |  | NULL | 学员标签：多个标签用逗号分隔，如：党员,干部,积极分子 |
| `role` | varchar(20) | NO | MUL | user | 角色，用户角色，admin为管理员，user为普通用户 |
| `avatar` | int | YES | MUL | NULL | 用户头像：关联到user_file表的id字段 |
| `created_at` | datetime | YES |  | CURRENT_TIMESTAMP | 用户创建时间，默认为当前时间 |


### AI生成内容表

### ai_tb_bank_questions

AI题库与题目对应关系表：存储AI题库包含的题目

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `bank_id` | int | NO | MUL | NULL | 外键，关联到AI题库表的id字段 |
| `question_id` | int | NO |  | NULL | 题目ID，对应不同题型表的id |
| `question_type` | tinyint | NO | MUL | NULL | 题目类型：1-单选题，2-多选题，3-判断题，4-简答题 |
| `sort_order` | int | YES |  | 0 | 题目在题库中的排序序号 |
| `created_at` | datetime | YES |  | CURRENT_TIMESTAMP | 创建时间，默认为当前时间 |


### ai_tb_banks

AI题库表：存储AI生成的题库信息

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `bank_name` | varchar(100) | NO | MUL | NULL | 题库名称 |
| `description` | text | YES |  | NULL | 题库描述 |
| `review_status` | tinyint | NO | MUL | 0 | 审核状态：0-待审核，1-审核通过，2-审核不通过 |
| `created_at` | datetime | YES |  | CURRENT_TIMESTAMP | 创建时间，默认为当前时间 |
| `updated_at` | datetime | YES |  | CURRENT_TIMESTAMP | 更新时间，默认当前时间，更新时自动更新 |


### ai_tb_essays

AI生成简答题表：存储AI生成的简答题信息

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `question_text` | text | NO |  | NULL | 题目内容 |
| `reference_answer` | text | NO |  | NULL | 参考答案，用于AI批改或人工参考 |
| `scoring_rule` | text | YES |  | NULL | 评分规则：用于存储简答题的评分标准和规则 |
| `score` | int | NO |  | 20 | 题目分值，默认20分 |
| `review_status` | tinyint | NO | MUL | 0 | 审核状态：0-待审核，1-审核通过，2-审核不通过 |
| `created_at` | datetime | YES |  | CURRENT_TIMESTAMP | 创建时间，默认为当前时间 |
| `updated_at` | datetime | YES |  | CURRENT_TIMESTAMP | 更新时间，默认当前时间，更新时自动更新 |


### ai_tb_judges

AI生成判断题表：存储AI生成的判断题信息

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `question_text` | text | NO |  | NULL | 题目内容 |
| `correct_answer` | tinyint | NO |  | NULL | 正确答案：1-正确，0-错误 |
| `explanation` | text | YES |  | NULL | 答案解析 |
| `score` | int | NO |  | 5 | 题目分值，默认5分 |
| `review_status` | tinyint | NO | MUL | 0 | 审核状态：0-待审核，1-审核通过，2-审核不通过 |
| `created_at` | datetime | YES |  | CURRENT_TIMESTAMP | 创建时间，默认为当前时间 |
| `updated_at` | datetime | YES |  | CURRENT_TIMESTAMP | 更新时间，默认当前时间，更新时自动更新 |


### ai_tb_multiple_choices

AI生成多选题表：存储AI生成的多选题信息

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `question_text` | text | NO |  | NULL | 题目内容 |
| `option_a` | text | NO |  | NULL | 选项A |
| `option_b` | text | NO |  | NULL | 选项B |
| `option_c` | text | NO |  | NULL | 选项C |
| `option_d` | text | NO |  | NULL | 选项D |
| `option_e` | text | NO |  | NULL | 选项E |
| `correct_answer` | varchar(20) | NO | MUL | NULL | 正确答案：多个选项用逗号分隔，如"A,B,D" |
| `explanation` | text | YES |  | NULL | 答案解析 |
| `score` | int | NO |  | 10 | 题目分值，默认10分 |
| `review_status` | tinyint | NO | MUL | 0 | 审核状态：0-待审核，1-审核通过，2-审核不通过 |
| `created_at` | datetime | YES |  | CURRENT_TIMESTAMP | 创建时间，默认为当前时间 |
| `updated_at` | datetime | YES |  | CURRENT_TIMESTAMP | 更新时间，默认当前时间，更新时自动更新 |


### ai_tb_single_choices

AI生成单选题表：存储AI生成的单选题信息

| 字段名 | 类型 | 允许空 | 键 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | int | NO | PRI | NULL | 主键ID，自增 |
| `question_text` | text | NO |  | NULL | 题目内容 |
| `option_a` | text | NO |  | NULL | 选项A |
| `option_b` | text | NO |  | NULL | 选项B |
| `option_c` | text | NO |  | NULL | 选项C |
| `option_d` | text | NO |  | NULL | 选项D |
| `correct_answer` | char(1) | NO |  | NULL | 正确答案：A/B/C/D |
| `explanation` | text | YES |  | NULL | 答案解析 |
| `score` | int | NO |  | 10 | 题目分值，默认10分 |
| `review_status` | tinyint | NO | MUL | 0 | 审核状态：0-待审核，1-审核通过，2-审核不通过 |
| `created_at` | datetime | YES |  | CURRENT_TIMESTAMP | 创建时间，默认为当前时间 |
| `updated_at` | datetime | YES |  | CURRENT_TIMESTAMP | 更新时间，默认当前时间，更新时自动更新 |


---

## 2. 评分生成原理

系统的评分逻辑分为两个独立阶段：**评分要点生成** 和 **学生答案评分**。

### 阶段一：评分要点生成 (Rubric Generation)
在对学生答案评分之前，系统首先需要理解参考答案。
1.  **输入**：参考答案 (`reference_answer`)。
2.  **处理**：LLM 将参考答案拆解为若干个关键评分点 (Rubric Points)，并为每个点分配权重（总权重 10 分）。
3.  **输出**：JSON 格式的评分标准，存储在 `rubric` 字段中。

### 阶段二：多维度评分 (Multi-dimensional Grading)
评分过程综合了三个维度的评估：

1.  **内容覆盖度 (Content Coverage) - 权重 80%**
    *   系统逐一对比学生答案与评分要点。
    *   LLM 判断学生是否覆盖了每个要点，并提取证据（原文引用）。
    *   计算公式：`ContentScore = Σ(覆盖度 × 权重)`。

2.  **答案质量 (Answer Quality) - 权重 10%**
    *   LLM 从逻辑性、表达清晰度、结构合理性、专业性四个维度对答案进行整体打分 (0-10 分)。

3.  **主题相关性 (Topic Relevance) - 权重 10%**
    *   使用 Embedding 模型计算学生答案与参考答案的余弦相似度。
    *   根据相似度阈值映射为 0-10 分（例如相似度 > 0.6 则得分 = 相似度 × 10）。

**最终得分公式：**
`FinalScore = (ContentScore * 0.8) + (QualityScore * 0.1) + (TopicScore * 0.1)`

---

## 3. 使用方式

系统采用分步执行的流程，确保数据的准确性和处理的可控性。

### 步骤 1：准备数据与环境
1.  确保已安装依赖：`pip install -r requirements.txt`
2.  配置 `.env` 文件，填入阿里云 DashScope API Key。
3.  使用 `test_exam_simulation.py` 模拟录入试题和学生答案。
    ```bash
    python test_exam_simulation.py
    ```
    *该脚本会向 MySQL 数据库的 `tb_essays` 和 `answers` 表插入新题目和学生答案，但不会自动评分。*

### 步骤 2：生成评分要点
运行生成器脚本，扫描所有未解析的题目并生成评分标准。
```bash
python rubric_generator.py
```
*   **输入**：`tb_essays` 表中 `is_rubric_parsed=0` 的题目。
*   **输出**：更新数据库，生成 `rubric`，设置 `is_rubric_parsed=1`。

### 步骤 3：执行自动评分
运行评分脚本，对未评分的学生答案进行打分。
```bash
python grade_answers.py
```
*   **输入**：`answers` 表中 `ai_final_score` 为空的记录。
*   **前置条件**：对应的题目必须已完成“步骤 2”的处理。
*   **输出**：计算最终得分，生成详细报告，并更新到数据库。

### 常见问题
*   **Q: 运行 `grade_answers.py` 提示 "Error: 题目 X 缺少评分要点"？**
    *   A: 说明该题目尚未生成评分标准。请先运行 `python rubric_generator.py`。
*   **Q: 如何查看评分结果？**
    *   A: 脚本运行结束后会在控制台打印简报，完整报告存储在 `answers` 表的 `ai_report` 字段中。

---

## 4. 标签提取与题目推荐系统

### 4.1 标签提取系统 (`extract_tags.py`)

#### 功能说明
该脚本用于从 `tb_single_choices` 表中读取所有记录，对每条记录的 `question_text` 进行标签提取，然后将提取的标签插入到 `tb_tags` 表中。

#### 主要方法

| 方法名 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `get_all_questions()` | 无 | `list` | 从数据库中获取 `tb_single_choices` 表的所有记录，返回包含 `id` 和 `question_text` 的字典列表 |
| `insert_tags(question_id, tags)` | `question_id`: 题目ID<br>`tags`: 标签列表，格式为 `[(tag1, score1), (tag2, score2), ...]` | `bool` | 将提取的标签插入到 `tb_tags` 表中，返回插入是否成功 |
| `extract_tags_jieba(text, top_n=20)` | `text`: 待提取标签的文本<br>`top_n`: 返回标签的数量，默认为20 | `list` | 使用 jieba 库提取标签，返回标签及其权重的列表 |
| `extract_tags_llm(text, top_n=10)` | `text`: 待提取标签的文本<br>`top_n`: 返回标签的数量，默认为10 | `list` | 使用中文大模型提取标签，返回标签及其权重的列表 |
| `main()` | 无 | 无 | 主函数，执行标签提取任务的完整流程 |

#### 使用方式
```bash
python extract_tags.py
```

#### 执行流程
1. 连接数据库并获取 `tb_single_choices` 表的所有记录
2. 对每条记录的 `question_text` 使用中文大模型提取标签
3. 将提取的标签插入到 `tb_tags` 表中
4. 输出处理结果统计信息

### 4.2 题目推荐系统 (`recommend_question.py`)

#### 功能说明
该脚本用于从 `choice_answers` 表中读取 `is_correct` 为 0 的记录，然后查询这些记录对应的 `question_id` 在 `tb_tags` 表中的所有 `question_tag` 值，最后根据这些标签查询其他相关的题目。

#### 主要方法

| 方法名 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `get_incorrect_answers()` | 无 | `list` | 获取 `choice_answers` 表中 `is_correct` 为 0 的记录的 `question_id` 列表（去重） |
| `get_tags_by_question_id(question_id)` | `question_id`: 题目ID | `list` | 获取指定 `question_id` 的所有标签，返回标签列表 |
| `get_question_ids_by_tag(tag)` | `tag`: 标签名称 | `list` | 获取包含指定标签的所有 `question_id`，返回题目ID列表 |
| `main()` | 无 | 无 | 主函数，执行题目推荐任务的完整流程 |

#### 使用方式
```bash
python recommend_question.py
```

#### 执行流程
1. 连接数据库并获取 `choice_answers` 表中 `is_correct` 为 0 的记录的 `question_id`
2. 对每个 `question_id` 查询对应的标签
3. 对每个标签查询包含该标签的其他题目ID
4. 对相关题目ID进行去重处理并显示
5. 输出处理结果统计信息

---

## 5. 系统整体流程

1. **数据准备**：确保 `tb_single_choices` 表中存在题目数据
2. **标签提取**：运行 `extract_tags.py` 提取题目标签
3. **答题记录**：学生答题后，`choice_answers` 表中会记录答题结果
4. **题目推荐**：运行 `recommend_question.py` 根据错误题目推荐相关题目

通过以上流程，系统可以为学生提供个性化的题目推荐，帮助学生针对薄弱知识点进行练习。
