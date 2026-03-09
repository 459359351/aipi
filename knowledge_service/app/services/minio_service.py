"""
MinIO 对象存储服务 —— 文件上传 / 下载 / 删除
"""

import io
import logging
from typing import BinaryIO

import urllib3
from minio import Minio
from minio.error import S3Error

from ..config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


class MinIOService:
    """MinIO 客户端封装"""

    def __init__(self):
        # 快速失败：连接超时 3s，不重试，避免启动/上传时卡住
        _http = urllib3.PoolManager(
            timeout=urllib3.util.Timeout(connect=3, read=30),
            retries=urllib3.util.Retry(total=0, raise_on_redirect=False),
        )
        self.client = Minio(
            endpoint=settings.MINIO_ENDPOINT,
            access_key=settings.MINIO_ACCESS_KEY,
            secret_key=settings.MINIO_SECRET_KEY,
            secure=settings.MINIO_SECURE,
            http_client=_http,
        )
        self.bucket = settings.MINIO_BUCKET

    def ensure_bucket(self) -> None:
        """确保 bucket 存在，不存在则创建"""
        try:
            if not self.client.bucket_exists(self.bucket):
                self.client.make_bucket(self.bucket)
                logger.info(f"MinIO bucket '{self.bucket}' 已创建")
        except S3Error as e:
            logger.error(f"MinIO bucket 初始化失败: {e}")
            raise

    def upload_file(
        self,
        object_key: str,
        data: BinaryIO,
        length: int,
        content_type: str = "application/octet-stream",
    ) -> str:
        """
        上传文件到 MinIO

        Args:
            object_key: 对象存储键（如 "2024/01/xxx.pdf"）
            data: 文件二进制流
            length: 文件大小（字节）
            content_type: MIME 类型

        Returns:
            完整的文件访问 URL
        """
        try:
            self.client.put_object(
                bucket_name=self.bucket,
                object_name=object_key,
                data=data,
                length=length,
                content_type=content_type,
            )
        except S3Error as e:
            # bucket 不存在时才尝试创建，其他错误直接抛出
            if e.code == "NoSuchBucket":
                logger.warning(f"Bucket '{self.bucket}' 不存在，尝试创建...")
                self.client.make_bucket(self.bucket)
                self.client.put_object(
                    bucket_name=self.bucket,
                    object_name=object_key,
                    data=data,
                    length=length,
                    content_type=content_type,
                )
            else:
                logger.error(f"文件上传失败: {e}")
                raise

        protocol = "https" if settings.MINIO_SECURE else "http"
        file_url = f"{protocol}://{settings.MINIO_ENDPOINT}/{self.bucket}/{object_key}"
        logger.info(f"文件上传成功: {object_key}")
        return file_url

    def download_file(self, object_key: str) -> bytes:
        """
        从 MinIO 下载文件

        Args:
            object_key: 对象存储键

        Returns:
            文件二进制内容
        """
        try:
            response = self.client.get_object(
                bucket_name=self.bucket,
                object_name=object_key,
            )
            data = response.read()
            response.close()
            response.release_conn()
            logger.info(f"文件下载成功: {object_key}")
            return data
        except S3Error as e:
            logger.error(f"文件下载失败: {e}")
            raise

    def delete_file(self, object_key: str) -> None:
        """
        从 MinIO 删除文件

        Args:
            object_key: 对象存储键
        """
        try:
            self.client.remove_object(
                bucket_name=self.bucket,
                object_name=object_key,
            )
            logger.info(f"文件删除成功: {object_key}")
        except S3Error as e:
            logger.error(f"文件删除失败: {e}")
            raise


# 全局单例
minio_service = MinIOService()
