import os
import dashscope
from dashscope import Generation
from http import HTTPStatus
import json
from typing import List, Union

# 加载环境变量
from dotenv import load_dotenv
load_dotenv()

api_key = os.getenv("DASHSCOPE_API_KEY")
if api_key:
    dashscope.api_key = api_key

def call_llm(prompt: str, model: str = "qwen3-max") -> str:
    """
    调用阿里云 Qwen LLM。
    """
    try:
        messages = [{'role': 'system', 'content': '你是一个乐于助人的助手。'},
                    {'role': 'user', 'content': prompt}]
        
        response = Generation.call(
            model=model,
            messages=messages,
            result_format='message',  # 设置结果为 "message" 格式
        )
        
        if response.status_code == HTTPStatus.OK:
            return response.output.choices[0]['message']['content']
        else:
            print(f"请求 ID: {response.request_id}, 状态码: {response.status_code}, 错误码: {response.code}, 错误信息: {response.message}")
            return ""
    except Exception as e:
        print(f"调用 LLM 时出错: {e}")
        return ""

def get_embedding(text: Union[str, List[str]], model: str = "text-embedding-v1") -> List[float]:
    """
    使用阿里云获取文本的 Embedding。
    """
    try:
        # text-embedding-v1 支持字符串列表或单个字符串
        # 如果输入是单个字符串，我们可能需要包装它或相应地处理响应。
        # 但 dashscope.TextEmbedding.call 的输入可以是字符串或列表。
        
        resp = dashscope.TextEmbedding.call(
            model=model,
            input=text
        )
        
        if resp.status_code == HTTPStatus.OK:
            # 如果输入是单个字符串，输出是包含一个项目的列表。
            # 我们返回 embedding 向量（浮点数列表）。
            # 结构是 resp.output['embeddings'][0]['embedding']
            if 'embeddings' in resp.output and len(resp.output['embeddings']) > 0:
                return resp.output['embeddings'][0]['embedding']
            return []
        else:
            print(f"请求 ID: {resp.request_id}, 状态码: {resp.status_code}, 错误码: {resp.code}, 错误信息: {resp.message}")
            return []
    except Exception as e:
        print(f"获取 Embedding 时出错: {e}")
        return []

if __name__ == "__main__":
    # 测试
    if not dashscope.api_key:
        print("请在 .env 文件中设置 DASHSCOPE_API_KEY")
    else:
        print("正在测试 LLM...")
        print(call_llm("你好，你是谁？"))
        print("正在测试 Embedding...")
        emb = get_embedding("你好世界")
        print(f"Embedding 长度: {len(emb)}")
