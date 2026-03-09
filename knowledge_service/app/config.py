"""
统一配置管理 —— 从 .env 文件加载所有环境变量
"""

from urllib.parse import quote_plus

from pydantic_settings import BaseSettings
from pydantic import Field
from functools import lru_cache


class Settings(BaseSettings):
    """应用配置，所有值均可通过环境变量或 .env 文件覆盖"""

    # ── 应用 ──────────────────────────────────────────────
    APP_NAME: str = "Knowledge Service"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False

    # ── MySQL ─────────────────────────────────────────────
    MYSQL_HOST: str = "127.0.0.1"
    MYSQL_PORT: int = 3306
    MYSQL_USER: str = "root"
    MYSQL_PASSWORD: str = ""
    MYSQL_DATABASE: str = "knowledge_service"

    @property
    def DATABASE_URL(self) -> str:
        # 对密码进行 URL 编码，避免特殊字符（如 @）破坏 URL 解析
        encoded_password = quote_plus(self.MYSQL_PASSWORD)
        return (
            f"mysql+pymysql://{self.MYSQL_USER}:{encoded_password}"
            f"@{self.MYSQL_HOST}:{self.MYSQL_PORT}/{self.MYSQL_DATABASE}"
            f"?charset=utf8mb4"
        )

    # ── MinIO ─────────────────────────────────────────────
    MINIO_ENDPOINT: str = "127.0.0.1:9000"
    MINIO_ACCESS_KEY: str = "minioadmin"
    MINIO_SECRET_KEY: str = "minioadmin"
    MINIO_BUCKET: str = "knowledge-docs"
    MINIO_SECURE: bool = False

    # ── Dify ──────────────────────────────────────────────
    DIFY_BASE_URL: str = "http://127.0.0.1/v1"
    DIFY_API_KEY: str = ""
    DIFY_DATASET_ID: str = ""

    # ── LLM (DashScope / Qwen) ────────────────────────────
    DASHSCOPE_API_KEY: str = ""
    LLM_MODEL: str = "qwen-max"

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "case_sensitive": True,
    }


@lru_cache()
def get_settings() -> Settings:
    """单例获取配置对象"""
    return Settings()
