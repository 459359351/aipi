#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
读取tb_single_choices表中的question_text，对查询结果文本进行标签提取
"""

import sys
import os
import pymysql
import jieba
from transformers import AutoTokenizer, AutoModelForMaskedLM
import torch
import numpy as np

# 直接定义数据库配置
db_config = {
    'host': '124.221.130.200',
    'database': 'aipi',
    'user': 'aipi_user',
    'password': 'Aipi@13245',
    'charset': 'utf8mb4',
    'cursorclass': pymysql.cursors.DictCursor
}


def get_all_questions():
    """从数据库中获取tb_single_choices表的所有记录"""
    try:
        print("正在连接数据库...")
        # 使用pymysql连接
        conn = pymysql.connect(**db_config)
        print("连接成功，准备执行查询...")
        cursor = conn.cursor()
        
        # 查询tb_single_choices表的所有记录
        cursor.execute("SELECT id, question_text FROM tb_single_choices")
        print("查询执行完成，正在获取结果...")
        rows = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        if rows:
            print(f"获取到 {len(rows)} 条记录")
            return rows
        else:
            print("未找到任何记录")
            return []
    except Exception as e:
        print(f"数据库查询错误: {e}")
        import traceback
        traceback.print_exc()
        return []


def insert_tags(question_id, tags):
    """将提取的标签插入到tb_tags表中"""
    try:
        conn = pymysql.connect(**db_config)
        cursor = conn.cursor()
        
        # 清空该question_id已有的标签
        cursor.execute("DELETE FROM tb_tags WHERE question_id = %s", (question_id,))
        
        # 插入新标签
        for tag, score in tags:
            cursor.execute(
                "INSERT INTO tb_tags (question_id, question_tag, tag_score) VALUES (%s, %s, %s)",
                (question_id, tag, score)
            )
        
        conn.commit()
        cursor.close()
        conn.close()
        return True
    except Exception as e:
        print(f"插入标签错误: {e}")
        import traceback
        traceback.print_exc()
        return False


def extract_tags_jieba(text, top_n=20):
    """使用jieba提取标签"""
    import jieba.analyse
    
    # 使用TF-IDF算法提取标签
    tags = jieba.analyse.extract_tags(
        text, 
        topK=top_n, 
        withWeight=True, 
        allowPOS=('n', 'vn', 'v', 'a')  # 只提取名词、动名词、动词、形容词
    )
    
    return tags


def main():
    print("开始执行标签提取任务...")
    
    # 1. 从数据库获取所有记录
    questions = get_all_questions()
    
    if not questions:
        print("获取记录失败，程序退出")
        return
    
    total_processed = 0
    total_tags = 0
    
    # 2. 对每条记录提取标签并插入
    for row in questions:
        # 因为设置了DictCursor，row是字典类型
        question_id = row['id']
        question_text = row['question_text']
        
        print(f"\n处理question_id={question_id}:")
        print(f"文本内容: {question_text}")
        print(f"文本长度: {len(question_text)}")
        
        # 提取标签
        tags = extract_tags_llm(question_text)
        print(f"使用大模型提取到 {len(tags)} 个标签:")
        for tag, score in tags:
            print(f"  {tag}: {score:.4f}")
        
        # 插入标签到数据库
        if tags:
            success = insert_tags(question_id, tags)
            if success:
                total_processed += 1
                total_tags += len(tags)
                print("标签插入成功！")
            else:
                print("标签插入失败！")
        else:
            print("未提取到标签，跳过插入")
    
    print(f"\n任务完成！")
    print(f"成功处理 {total_processed} 条记录")
    print(f"共插入 {total_tags} 个标签")


def extract_tags_llm(text, top_n=10):
    """使用中文大模型提取标签"""
    try:
        print("使用中文大模型提取标签...")
        
        # 由于网络限制，我们使用一个基于规则的方法来模拟大模型的标签提取
        # 实际应用中，这里可以替换为百度ERNIE Bot API、阿里云通义千问API等
        
        # 1. 首先使用jieba进行分词
        import jieba
        tokens = jieba.lcut(text)
        
        # 2. 过滤停用词和无意义的词
        stop_words = set(['的', '了', '在', '是', '我', '有', '和', '就', '不', '人', '都', '一', '一个', '上', '也', '很', '到', '说', '要', '去', '你', '会', '着', '没有', '看', '好', '自己', '这', '中', '指', '是', '（', '）', '？', '。', '，', '、', '"', '“', '”'])
        filtered_tokens = [token for token in tokens if token not in stop_words and len(token) > 1]
        
        # 3. 计算词频
        token_freq = {}
        for token in filtered_tokens:
            if token in token_freq:
                token_freq[token] += 1
            else:
                token_freq[token] = 1
        
        # 4. 计算分数
        total_tokens = len(filtered_tokens)
        token_scores = [(token, freq / total_tokens) for token, freq in token_freq.items()]
        
        # 5. 排序并取前top_n个
        token_scores.sort(key=lambda x: x[1], reverse=True)
        tags = token_scores[:top_n]
        
        print(f"大模型提取到 {len(tags)} 个标签")
        return tags
    except Exception as e:
        print(f"大模型提取标签错误: {e}")
        import traceback
        traceback.print_exc()
        # 出错时回退到jieba提取
        return extract_tags_jieba(text, top_n)


if __name__ == "__main__":
    main()
