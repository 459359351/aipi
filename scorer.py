import json
import numpy as np
from decimal import Decimal, ROUND_CEILING
from sklearn.metrics.pairwise import cosine_similarity
from llm_utils import call_llm, get_embedding
import re

class AnswerScorer:
    def __init__(self, enable_content=True, enable_quality=True, enable_topic=True):
        self.config = {
            "content": enable_content,
            "quality": enable_quality,
            "topic": enable_topic
        }
        # 默认权重
        self.default_weights = {
            "content": 0.80,
            "quality": 0.10,
            "topic": 0.10
        }

    def _round_one(self, value) -> float:
        """
        辅助方法: 保留一位小数，向上取整 (ROUND_CEILING)
        """
        try:
            return float(Decimal(str(value)).quantize(Decimal("0.1"), rounding=ROUND_CEILING))
        except:
            return float(value)

    def _round_int(self, value) -> int:
        """
        辅助方法: 取整，向上取整 (ROUND_CEILING)
        """
        try:
            return int(Decimal(str(value)).quantize(Decimal("1"), rounding=ROUND_CEILING))
        except:
            return int(value)

    def preprocess_text(self, text: str) -> str:
        """
        步骤 0: 文本预处理
        去除多余空格，修剪文本。
        """
        if not text:
            return ""
        # 去除多余的空白字符
        text = re.sub(r'\s+', ' ', text).strip()
        return text

    def generate_rubric(self, reference_answer: str) -> list:
        """
        步骤 1: 使用 LLM 将参考答案拆分为评分要点（Rubric）。
        返回字典列表: [{'point': str, 'weight': int}]
        """
        prompt = f"""
        任务：将以下参考答案拆分为用于评分的关键要点（Rubric）列表。
        为每个要点分配权重，使得总权重之和为 10。
        
        参考答案：
        {reference_answer}
        
        输出格式：包含对象的 JSON 列表，每个对象包含 "point"（字符串描述）和 "weight"（整数）。
        示例：
        [
            {{"point": "概念定义", "weight": 2}},
            {{"point": "原因分析", "weight": 3}}
        ]
        
        仅返回 JSON 数据。
        """
        response = call_llm(prompt)
        try:
            # 清理可能存在的 markdown 代码块
            response = response.replace("```json", "").replace("```", "").strip()
            rubric = json.loads(response)
            return rubric
        except Exception as e:
            print(f"解析评分要点生成时出错: {e}")
            print(f"原始响应: {response}")
            # 兜底策略：将整段文本视为一个要点
            return [{"point": reference_answer, "weight": 10}]

    def evaluate_coverage(self, db_manager, student_result_id: int) -> list:
        """
        步骤 2: LLM 评估每个要点的覆盖情况。
        从数据库读取数据进行评估
        """
        student_result = db_manager.get_student_result(student_result_id)
        if not student_result:
            print(f"Error: Student result {student_result_id} not found")
            return []
            
        question = db_manager.get_question_as_dict(student_result['question_id'])
        if not question:
            print(f"Error: Question {student_result['question_id']} not found")
            return []

        rubric_json = question.get('rubric')
        if not rubric_json:
             print(f"Error: Rubric not found for question {student_result['question_id']}. Cannot score.")
             return []
        else:
             rubric = json.loads(rubric_json)
             
        student_answer = self.preprocess_text(student_result['student_answer'])
        
        results = []
        for item in rubric:
            point = item['point']
            weight = item['weight']
            
            prompt = f"""
            任务：评估学生答案是否覆盖了该关键要点，或者同义表达。
            
            关键要点：{point}
            
            学生答案：
            {student_answer}
            
            评判不要过于严格，适当宽松，包含或者同义表达都算命中，覆盖率（0.0 到 1.0）并提取证据（学生答案中的引用）。
            输出格式：包含 "coverage"（浮点数）和 "evidence"（字符串）的 JSON 对象。
            如果没有证据，将 evidence 设为空字符串。
            
            仅返回 JSON 数据。
            """
            
            response = call_llm(prompt)
            try:
                response = response.replace("```json", "").replace("```", "").strip()
                eval_result = json.loads(response)
                
                results.append({
                    "point": point,
                    "weight": weight,
                    "coverage": float(eval_result.get("coverage", 0.0)),
                    "evidence": eval_result.get("evidence", "")
                })
            except Exception as e:
                print(f"评估要点 '{point}' 的覆盖率时出错: {e}")
                results.append({
                    "point": point,
                    "weight": weight,
                    "coverage": 0.0,
                    "evidence": ""
                })
        return results

    def calculate_content_score(self, coverage_results: list) -> float:
        """
        步骤 3: 计算内容得分 (ContentScore)
        将得分归一化到 0-10 范围，防止因权重之和不为 10 导致总分溢出。
        """
        total_score = 0.0
        total_weight = 0.0
        for item in coverage_results:
            total_score += item['coverage'] * item['weight']
            total_weight += item['weight']
        
        if total_weight == 0:
            return 0.0
        
        # 归一化计算：(实际得分 / 总权重) * 10
        normalized_score = (total_score / total_weight) * 10.0
        
        # 保留一位小数
        return self._round_one(normalized_score)

    def evaluate_quality(self, student_answer: str) -> float:
        """
        步骤 4: LLM 质量评分 (0-10)
        """
        prompt = f"""
        任务：基于以下维度评估学生答案的质量：
        1. 逻辑性
        2. 表达清晰度
        3. 结构合理性
        4. 专业性
        
        学生答案：
        {student_answer}
        
        给出一个 0 到 10 的整体评分。
        输出格式：包含 "score"（浮点数）的 JSON 对象。
        
        仅返回 JSON 数据。
        """
        response = call_llm(prompt)
        try:
            response = response.replace("```json", "").replace("```", "").strip()
            result = json.loads(response)
            score = float(result.get("score", 0.0))
            # 确保分数在 0-10 范围内，并保留一位小数
            clamped_score = min(max(score, 0.0), 10.0)
            return self._round_one(clamped_score)
        except Exception as e:
            print(f"评估质量时出错: {e}")
            return 5.0 # 默认兜底值

    def calculate_topic_relevance(self, reference_answer: str, student_answer: str) -> dict:
        """
        步骤 5: Embedding 主题相关度评分
        """
        # 5.1 生成向量
        # 对于参考答案，可以使用全文或摘要。用户建议“摘要或合并要点”。
        # 为简单起见，我使用参考答案全文作为标准。
        r_vec = get_embedding(reference_answer)
        s_vec = get_embedding(student_answer)
        
        if not r_vec or not s_vec:
            return {"sim": 0.0, "score": 0.0}
        
        # 5.2 计算余弦相似度
        # 调整形状以适应 sklearn
        r_vec = np.array(r_vec).reshape(1, -1)
        s_vec = np.array(s_vec).reshape(1, -1)
        
        sim = cosine_similarity(r_vec, s_vec)[0][0]
        
        # 5.3 评分映射与阈值
        score = 0.0
        if sim < 0.4:
            score = 2.0
        elif sim < 0.6:
            score = 6.0
        else:
            score = sim * 10.0
            
        return {"sim": sim, "score": self._round_one(score)}

    def calculate_final_score(self, content_score, quality_score, topic_score) -> int:
        """
        步骤 6: 融合得分
        根据配置动态调整权重
        """
        # 1. 确定启用的组件和原始总权重
        active_weights = 0.0
        if self.config['content']:
            active_weights += self.default_weights['content']
        if self.config['quality']:
            active_weights += self.default_weights['quality']
        if self.config['topic']:
            active_weights += self.default_weights['topic']
            
        if active_weights == 0:
            return 0
            
        # 2. 重新归一化权重并计算加权和
        final = 0.0
        
        if self.config['content']:
            # 新权重 = 原始权重 / 启用总权重
            w = self.default_weights['content'] / active_weights
            final += content_score * w
            
        if self.config['quality']:
            w = self.default_weights['quality'] / active_weights
            final += quality_score * w
            
        if self.config['topic']:
            w = self.default_weights['topic'] / active_weights
            final += topic_score * w
            
        # 使用标准的向上取整 (ROUND_CEILING)，取整
        return self._round_int(final)

    def generate_report(self, coverage_results, content_score, quality_score, topic_data, final_score) -> str:
        """
        步骤 7: 可解释性报告
        """
        # 统一保留一位小数 (使用标准四舍五入)
        content_score = self._round_one(content_score)
        quality_score = self._round_one(quality_score)
        topic_score = self._round_one(topic_data['score'])
        
        final_score = int(final_score)
        
        report = []
        report.append("# 评分报告 (Grading Report)")
        report.append(f"**最终得分 (Final Score):** {final_score} / 10")
        report.append("-" * 20)
        
        if self.config['content']:
            report.append("## 1. 内容覆盖明细 (Content Coverage)")
            for item in coverage_results:
                status = "✅" if item['coverage'] > 0.7 else ("⚠️" if item['coverage'] > 0.3 else "❌")
                report.append(f"- {status} **{item['point']}** (权重: {item['weight']})")
                report.append(f"  - 覆盖度: {item['coverage']:.2f}")
                if item['evidence']:
                    report.append(f"  - 证据: \"{item['evidence']}\"")
                else:
                    report.append(f"  - 证据: (未找到相关描述)")
            report.append(f"**内容得分:** {content_score}")
            report.append("-" * 20)
        
        if self.config['quality']:
            report.append("## 2. 质量评估 (Quality Assessment)")
            report.append(f"**质量得分:** {quality_score}")
            report.append("(基于逻辑、表达、结构、专业性综合评分)")
            report.append("-" * 20)
        
        if self.config['topic']:
            report.append("## 3. 主题相关度 (Topic Relevance)")
            report.append(f"**Embedding 相似度:** {topic_data['sim']:.4f}")
            report.append(f"**主题得分:** {topic_score}")
        
        return "\n".join(report)

    def score(self, db_manager, student_result_id: int):
        # Retrieve necessary text for other steps
        student_result = db_manager.get_student_result(student_result_id)
        if not student_result:
            print(f"Error: Student result {student_result_id} not found")
            return None
            
        question = db_manager.get_question_as_dict(student_result['question_id'])
        if not question:
            print(f"Error: Question {student_result['question_id']} not found")
            return None
            
        reference_answer = question['reference_answer']
        student_answer = student_result['student_answer']

        # 步骤 0
        ref_clean = self.preprocess_text(reference_answer)
        stu_clean = self.preprocess_text(student_answer)
        
        print("--- 步骤 1: 检查评分要点 ---")
        if not question.get('rubric'):
             print(f"Error: 题目 {question['id']} 缺少评分要点，无法进行评分。")
             return None
        print("评分要点已存在。")
        
        print("--- 步骤 2: 评估覆盖率 ---")
        coverage_results = self.evaluate_coverage(db_manager, student_result_id)
        
        if not coverage_results:
            print("覆盖率评估失败或返回空结果。")
            return None
        
        print("--- 步骤 3: 计算内容得分 ---")
        if self.config['content']:
            content_score = self.calculate_content_score(coverage_results)
            print(f"内容得分: {content_score}")
        else:
            content_score = 0.0
            print("内容评分已禁用。")
        
        print("--- 步骤 4: 评估质量得分 ---")
        if self.config['quality']:
            quality_score = self.evaluate_quality(stu_clean)
            print(f"质量得分: {quality_score}")
        else:
            quality_score = 0.0
            print("质量评分已禁用。")
        
        print("--- 步骤 5: 主题相关度 ---")
        if self.config['topic']:
            topic_data = self.calculate_topic_relevance(ref_clean, stu_clean)
            print(f"主题得分: {topic_data['score']} (相似度: {topic_data['sim']:.2f})")
        else:
            topic_data = {"score": 0.0, "sim": 0.0}
            print("主题评分已禁用。")
        
        print("--- 步骤 6: 最终得分 ---")
        final_score = self.calculate_final_score(content_score, quality_score, topic_data['score'])
        print(f"最终得分: {final_score}")
        
        print("--- 步骤 7: 生成报告 ---")
        report = self.generate_report(coverage_results, content_score, quality_score, topic_data, final_score)
        
        return {
            "final_score": final_score,
            "report": report,
            "details": {
                "content_score": content_score,
                "quality_score": quality_score,
                "topic_score": topic_data['score'],
                "rubric_breakdown": coverage_results
            }
        }
