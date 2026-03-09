from scorer import AnswerScorer
from database import MySQLDatabaseManager
import os
import sys

def main():
    print("正在初始化...")
    
    # 1. 初始化数据库
    db = MySQLDatabaseManager()
    
    # 2. 初始化评分器
    scorer = AnswerScorer()
    
    # 3. 模拟数据：设置一场新考试题目
    # MySQL 适配版：直接插入题目到 tb_essays 表，不涉及 exam 概念
    
    question_text = "简述监督学习与非监督学习的主要区别。"
    reference_answer = """
    监督学习（Supervised Learning）和非监督学习（Unsupervised Learning）的主要区别在于训练数据是否带有标签。
    1. 监督学习：使用带有标签（Label）的数据集进行训练。模型通过学习输入和输出之间的映射关系，来预测新的未知数据的输出。典型任务包括分类（Classification）和回归（Regression）。
    2. 非监督学习：使用没有标签的数据集进行训练。模型试图发现数据中的内在结构、模式或分布。典型任务包括聚类（Clustering）和降维（Dimensionality Reduction）。
    简单来说，监督学习像是有老师指导的学习，而非监督学习像是自学。
    """
    
    # 将题目存入数据库
    print(f"\n[DB] 正在存入新试题 (tb_essays)")
    # 注意：此时 is_rubric_parsed 默认为 0
    question_id = db.add_question(question_text, reference_answer)
    print(f"[DB] 试题存储成功，ID: {question_id}")
    
    # 4. 模拟考生答题
    user_id = 10086 # 模拟用户ID
    student_answer = """
    监督学习就是数据有标签，比如猫和狗的图片都标好了。非监督学习就是数据没标签，让机器自己找规律，比如把相似的图片分在一起。
    监督学习用来做分类，非监督学习用来做聚类。
    """
    
    print(f"\n[考生ID: {user_id}] 正在提交答案...")
    # MySQL 适配版：提交到 answers 表
    result_id = db.submit_student_answer(user_id, question_id, student_answer)
    print(f"[DB] 答案提交成功，记录 ID: {result_id}")
    
    print("\n数据准备完成。请依次运行以下脚本进行处理：")
    print("1. python grade_answers.py (预期失败，因为未解析评分要点)")
    print("2. python rubric_generator.py (生成评分要点)")
    print("3. python grade_answers.py (预期成功)")

if __name__ == "__main__":
    # 检查 API Key
    if not os.getenv("DASHSCOPE_API_KEY"):
        print("警告: 环境变量或 .env 文件中未设置 DASHSCOPE_API_KEY。")
        print("脚本可能会失败或返回空结果。")
    
    main()
