from database import MySQLDatabaseManager
from scorer import AnswerScorer

def main():
    print("启动自动评分服务 (MySQL版)...")
    
    # 初始化
    db = MySQLDatabaseManager()
    scorer = AnswerScorer()
    
    # 获取未评分的学生提交
    ungraded_results = db.get_ungraded_results()
    
    if not ungraded_results:
        print("没有发现未评分的提交。")
        return

    print(f"发现 {len(ungraded_results)} 个待评分提交。")
    
    for result_row in ungraded_results:
        result_id = result_row['id']
        student_name = result_row['student_name']
        question_id = result_row['question_id']
        
        print(f"\n正在处理: 学生 {student_name} (ID: {result_id}), 题目 ID: {question_id}")
        
        try:
            # 调用评分器
            # 注意: scorer.score 内部会检查 rubric 是否存在，不存在则返回 None
            score_result = scorer.score(db, result_id)
            
            if score_result:
                # 更新数据库
                db.update_student_score(result_id, score_result)
                print(f"评分成功。最终得分: {score_result['final_score']}")
            else:
                print(f"评分跳过: 可能题目 {question_id} 尚未解析评分要点。")
                
        except Exception as e:
            print(f"处理提交 ID {result_id} 时出错: {e}")
            import traceback
            traceback.print_exc()

if __name__ == "__main__":
    main()
