#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
读取choice_answers表中is_correct为0的记录，查询对应question_id的所有标签
"""

import sys
import os
import pymysql

# 数据库配置
db_config = {
    'host': '124.221.130.200',
    'database': 'aipi',
    'user': 'aipi_user',
    'password': 'Aipi@13245',
    'charset': 'utf8mb4',
    'cursorclass': pymysql.cursors.DictCursor
}


def get_incorrect_answers():
    """获取choice_answers表中is_correct为0的记录"""
    try:
        print("正在连接数据库...")
        conn = pymysql.connect(**db_config)
        cursor = conn.cursor()
        
        # 查询is_correct为0的记录
        cursor.execute("SELECT question_id FROM choice_answers WHERE is_correct = 0")
        rows = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        if rows:
            print(f"获取到 {len(rows)} 条错误记录")
            # 去重，获取唯一的question_id
            question_ids = list(set([row['question_id'] for row in rows]))
            print(f"唯一的question_id数量: {len(question_ids)}")
            return question_ids
        else:
            print("未找到错误记录")
            return []
    except Exception as e:
        print(f"数据库查询错误: {e}")
        import traceback
        traceback.print_exc()
        return []


def get_tags_by_question_id(question_id):
    """获取指定question_id的所有标签"""
    try:
        conn = pymysql.connect(**db_config)
        cursor = conn.cursor()
        
        # 查询指定question_id的标签
        cursor.execute("SELECT question_tag FROM tb_tags WHERE question_id = %s", (question_id,))
        rows = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        if rows:
            tags = [row['question_tag'] for row in rows]
            return tags
        else:
            return []
    except Exception as e:
        print(f"查询标签错误: {e}")
        import traceback
        traceback.print_exc()
        return []


def get_question_ids_by_tag(tag):
    """获取包含指定标签的所有question_id"""
    try:
        conn = pymysql.connect(**db_config)
        cursor = conn.cursor()
        
        # 查询包含指定标签的question_id
        cursor.execute("SELECT DISTINCT question_id FROM tb_tags WHERE question_tag = %s", (tag,))
        rows = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        if rows:
            question_ids = [row['question_id'] for row in rows]
            return question_ids
        else:
            return []
    except Exception as e:
        print(f"根据标签查询question_id错误: {e}")
        import traceback
        traceback.print_exc()
        return []


def main():
    print("开始执行题目推荐任务...")
    
    # 1. 获取所有错误记录的question_id
    question_ids = get_incorrect_answers()
    
    if not question_ids:
        print("无错误记录，程序退出")
        return
    
    # 2. 对每个question_id查询对应的标签
    total_processed = 0
    total_tags = 0
    total_related_questions = 0
    
    for question_id in question_ids:
        print(f"\n处理question_id={question_id}:")
        
        # 查询标签
        tags = get_tags_by_question_id(question_id)
        
        if tags:
            print(f"找到 {len(tags)} 个标签:")
            
            # 存储所有相关的question_id，用于去重
            all_related_question_ids = set()
            
            for tag in tags:
                print(f"  - {tag}")
                
                # 查询包含该标签的所有question_id
                related_question_ids = get_question_ids_by_tag(tag)
                
                if related_question_ids:
                    # 过滤掉当前的question_id，只显示其他相关的
                    filtered_ids = [qid for qid in related_question_ids if qid != question_id]
                    
                    if filtered_ids:
                        print(f"    包含该标签的其他题目ID: {filtered_ids}")
                        all_related_question_ids.update(filtered_ids)
                    else:
                        print(f"    无其他包含该标签的题目")
                else:
                    print(f"    无包含该标签的题目")
            
            # 显示去重后的相关题目ID
            if all_related_question_ids:
                unique_related_ids = sorted(list(all_related_question_ids))
                print(f"\n去重后的相关题目ID: {unique_related_ids}")
                total_related_questions += len(unique_related_ids)
            
            total_processed += 1
            total_tags += len(tags)
        else:
            print("未找到对应的标签")
    
    print(f"\n任务完成！")
    print(f"成功处理 {total_processed} 个question_id")
    print(f"共找到 {total_tags} 个标签")
    print(f"共找到 {total_related_questions} 个相关题目")


if __name__ == "__main__":
    main()
