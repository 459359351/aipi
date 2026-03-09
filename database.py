import json
import mysql.connector
from datetime import datetime

class MySQLDatabaseManager:
    def __init__(self):
        self.config = {
            'host': '124.221.130.200', # 请修改为新的数据库IP
            'database': 'aipi',
            'user': 'aipi_user',
            'password': 'Aipi@13245'
        }

    def get_connection(self):
        return mysql.connector.connect(**self.config)

    def check_and_update_schema(self):
        """检查并更新数据库表结构，补充缺失字段"""
        conn = self.get_connection()
        try:
            cursor = conn.cursor()
            
            # 辅助函数：尝试添加字段，如果存在则忽略
            def add_column_safe(table, column_spec):
                column_name = column_spec.split()[0]
                try:
                    print(f"正在为表 {table} 添加字段 {column_name}...")
                    cursor.execute(f"ALTER TABLE {table} ADD COLUMN {column_spec}")
                    print(f"成功添加字段: {column_name}")
                except mysql.connector.Error as err:
                    # 1060: Duplicate column name
                    if err.errno == 1060:
                        print(f"字段已存在: {column_name} (跳过)")
                    else:
                        print(f"添加字段 {column_name} 失败: {err}")

            # 1. 补充 tb_essays 表字段 (对应 SQLite 的 exam_questions)
            add_column_safe("tb_essays", "rubric JSON COMMENT '评分标准'")
            add_column_safe("tb_essays", "is_rubric_parsed TINYINT(1) DEFAULT 0 COMMENT '是否已解析评分要点'")
            
            # 2. 补充 answers 表字段 (对应 SQLite 的 student_results)
            # 注意：MySQL 中建议明确指定 DECIMAL 精度
            add_column_safe("answers", "ai_content_score DECIMAL(5,1) COMMENT '内容得分'")
            add_column_safe("answers", "ai_quality_score DECIMAL(5,1) COMMENT '质量得分'")
            add_column_safe("answers", "ai_topic_score DECIMAL(5,1) COMMENT '主题得分'")
            add_column_safe("answers", "ai_final_score INT COMMENT '最终得分'")
            add_column_safe("answers", "ai_report TEXT COMMENT '评分报告'")
            add_column_safe("answers", "ai_details JSON COMMENT '评分详情'")
            
            conn.commit()
            print("数据库表结构检查/更新完成。")
            
        finally:
            if conn.is_connected():
                cursor.close()
                conn.close()

    def get_unparsed_questions(self):
        """获取所有未解析评分要点的题目 (MySQL tb_essays)"""
        conn = self.get_connection()
        try:
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SELECT * FROM tb_essays WHERE is_rubric_parsed = 0")
            rows = cursor.fetchall()
            return rows
        finally:
            if conn.is_connected():
                cursor.close()
                conn.close()

    def update_question_rubric(self, question_id, rubric_json):
        """更新题目的评分要点 (MySQL tb_essays)"""
        conn = self.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute("UPDATE tb_essays SET rubric = %s, is_rubric_parsed = 1 WHERE id = %s", (rubric_json, question_id))
            conn.commit()
        finally:
            if conn.is_connected():
                cursor.close()
                conn.close()

    def get_ungraded_results(self):
        """获取所有未评分的学生提交 (MySQL answers, ai_final_score IS NULL)"""
        conn = self.get_connection()
        try:
            cursor = conn.cursor(dictionary=True)
            # 注意：这里我们假设 ai_final_score 为空表示未评分
            # 同时需要获取学生答案 user_answer 和关联的题目信息
            # 为了兼容 scorer.py，我们需要将 user_answer 映射为 student_answer
            # 将 user_id (或别的字段) 映射为 student_name (暂时用 user_id 转字符串)
            cursor.execute("""
                SELECT id, user_id, question_id, user_answer as student_answer
                FROM answers 
                WHERE ai_final_score IS NULL
            """)
            rows = cursor.fetchall()
            # 简单处理 student_name
            for row in rows:
                row['student_name'] = f"User_{row['user_id']}"
            return rows
        finally:
            if conn.is_connected():
                cursor.close()
                conn.close()

    def get_student_result(self, result_id):
        """获取单个学生提交详情 (MySQL answers)"""
        conn = self.get_connection()
        try:
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SELECT id, user_id, question_id, user_answer as student_answer FROM answers WHERE id = %s", (result_id,))
            row = cursor.fetchone()
            if row:
                row['student_name'] = f"User_{row['user_id']}"
            return row
        finally:
            if conn.is_connected():
                cursor.close()
                conn.close()

    def get_question_as_dict(self, question_id):
        """获取题目详情 (MySQL tb_essays)"""
        conn = self.get_connection()
        try:
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SELECT * FROM tb_essays WHERE id = %s", (question_id,))
            row = cursor.fetchone()
            return row
        finally:
            if conn.is_connected():
                cursor.close()
                conn.close()

    def update_student_score(self, result_id, scoring_result):
        """更新学生评分结果 (MySQL answers)"""
        conn = self.get_connection()
        try:
            cursor = conn.cursor()
            
            details_json = json.dumps(scoring_result.get('details', {}), ensure_ascii=False)
            
            cursor.execute("""
                UPDATE answers
                SET 
                    ai_content_score = %s,
                    ai_quality_score = %s,
                    ai_topic_score = %s,
                    ai_final_score = %s,
                    ai_report = %s,
                    ai_details = %s
                WHERE id = %s
            """, (
                scoring_result['details']['content_score'],
                scoring_result['details']['quality_score'],
                scoring_result['details']['topic_score'],
                scoring_result['final_score'],
                scoring_result['report'],
                details_json,
                result_id
            ))
            conn.commit()
        finally:
            if conn.is_connected():
                cursor.close()
                conn.close()

    def add_question(self, question_text, reference_answer, rubric=None):
        """添加试题 (MySQL tb_essays)"""
        conn = self.get_connection()
        try:
            cursor = conn.cursor()
            
            rubric_json = json.dumps(rubric, ensure_ascii=False) if rubric else None
            is_rubric_parsed = 1 if rubric else 0
            
            # 注意: tb_essays 表中 score 字段非空且默认值为 20，这里我们使用默认值
            cursor.execute('''
                INSERT INTO tb_essays (question_text, reference_answer, rubric, is_rubric_parsed)
                VALUES (%s, %s, %s, %s)
            ''', (question_text, reference_answer, rubric_json, is_rubric_parsed))
            
            question_id = cursor.lastrowid
            conn.commit()
            return question_id
        finally:
            if conn.is_connected():
                cursor.close()
                conn.close()

    def submit_student_answer(self, user_id, question_id, user_answer):
        """提交学生答案 (MySQL answers)"""
        conn = self.get_connection()
        try:
            cursor = conn.cursor()
            
            # 注意: answers 表中 score 字段非空，这里暂时设为 0
            # user_id 必须为整数
            cursor.execute('''
                INSERT INTO answers (user_id, question_id, user_answer, score)
                VALUES (%s, %s, %s, %s)
            ''', (user_id, question_id, user_answer, 0))
            
            result_id = cursor.lastrowid
            conn.commit()
            return result_id
        finally:
            if conn.is_connected():
                cursor.close()
                conn.close()

if __name__ == "__main__":
    # 简单测试
    db = MySQLDatabaseManager()
    print("数据库连接配置:", db.config)

