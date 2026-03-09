import json
from database import MySQLDatabaseManager
from scorer import AnswerScorer

def main():
    print("启动评分要点生成服务 (MySQL版)...")
    
    # 初始化
    db = MySQLDatabaseManager()
    scorer = AnswerScorer()
    
    # 获取未解析的题目
    questions = db.get_unparsed_questions()
    
    if not questions:
        print("没有发现未解析评分要点的题目。")
        return

    print(f"发现 {len(questions)} 道待处理题目。")
    
    for q in questions:
        q_id = q['id']
        ref_answer = q['reference_answer']
        
        print(f"正在处理题目 ID: {q_id} ...")
        
        try:
            # 生成评分要点
            rubric = scorer.generate_rubric(ref_answer)
            
            # 序列化为 JSON
            rubric_json = json.dumps(rubric, ensure_ascii=False)
            
            # 更新数据库
            db.update_question_rubric(q_id, rubric_json)
            print(f"题目 ID {q_id} 解析完成并保存。")
            
        except Exception as e:
            print(f"处理题目 ID {q_id} 时出错: {e}")

if __name__ == "__main__":
    main()
