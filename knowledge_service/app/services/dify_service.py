"""
Dify 知识库 API 集成服务 —— 将知识点写入 Dify Dataset
"""

import logging
import time
from typing import Optional

import httpx

from ..config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

class DifyService:
    """Dify 知识库 API 客户端"""

    def __init__(self):
        self.base_url = settings.DIFY_BASE_URL.rstrip("/")
        self.api_key = settings.DIFY_API_KEY
        self.dataset_id = settings.DIFY_DATASET_ID
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

    def create_document_by_text(
        self,
        title: str,
        text: str,
    ) -> Optional[str]:
        """
        通过文本内容在 Dify 知识库中创建文档

        API: POST /datasets/{dataset_id}/document/create_by_text

        Args:
            title: 文档标题
            text: 文档正文内容

        Returns:
            Dify 返回的 document_id，失败返回 None
        """
        url = f"{self.base_url}/datasets/{self.dataset_id}/document/create_by_text"

        payload = {
            "name": title,
            "text": text,
            "indexing_technique": "high_quality",
            "process_rule": {
                "mode": "automatic",
            },
        }

        try:
            t0 = time.time()
            with httpx.Client(timeout=60.0) as client:
                response = client.post(url, json=payload, headers=self.headers)
            elapsed = time.time() - t0

            if response.status_code in (200, 201):
                data = response.json()
                doc_id = data.get("document", {}).get("id")
                if doc_id:
                    logger.info(f"[Dify] 文档创建成功: title='{title[:30]}', dify_doc_id='{doc_id}', 耗时 {elapsed:.1f}s")
                    return doc_id
                else:
                    logger.warning(f"[Dify] 返回数据中无 document.id: {data}")
                    return None
            else:
                logger.error(
                    f"[Dify] API 调用失败: status={response.status_code}, "
                    f"耗时 {elapsed:.1f}s, body={response.text[:500]}"
                )
                return None

        except httpx.TimeoutException:
            logger.error(f"[Dify] API 请求超时 (>60s): title='{title[:30]}'")
            return None
        except Exception as e:
            logger.error(f"[Dify] API 调用异常: {e}")
            return None

    def delete_document(self, dify_doc_id: str) -> bool:
        """
        从 Dify 知识库中删除文档

        API: DELETE /datasets/{dataset_id}/documents/{document_id}

        失败时仅 warning 不抛异常，保证调用方主流程不中断。
        """
        url = f"{self.base_url}/datasets/{self.dataset_id}/documents/{dify_doc_id}"
        try:
            with httpx.Client(timeout=30.0) as client:
                response = client.delete(url, headers=self.headers)

            if response.status_code in (200, 204):
                logger.info(f"Dify 文档删除成功: dify_doc_id='{dify_doc_id}'")
                return True
            else:
                logger.warning(
                    f"Dify 文档删除失败: dify_doc_id='{dify_doc_id}', "
                    f"status={response.status_code}, body={response.text[:300]}"
                )
                return False
        except Exception as e:
            logger.warning(f"Dify 文档删除异常: dify_doc_id='{dify_doc_id}', error={e}")
            return False

    def write_knowledge_point(
        self,
        title: str,
        content: str,
        summary: str = "",
        tags: list[str] | None = None,
    ) -> Optional[str]:
        """
        将单个知识点写入 Dify 知识库

        Args:
            title: 知识点标题
            content: 知识点内容
            summary: 知识点摘要
            tags: 标签列表

        Returns:
            Dify document_id，失败返回 None
        """
        # 组装写入 Dify 的文本（将结构化信息拼接为一段文本）
        parts = [f"# {title}"]
        if summary:
            parts.append(f"\n摘要：{summary}")
        if tags:
            parts.append(f"\n标签：{', '.join(tags)}")
        parts.append(f"\n\n{content}")

        full_text = "\n".join(parts)
        return self.create_document_by_text(title=title, text=full_text)


# 全局单例
dify_service = DifyService()
