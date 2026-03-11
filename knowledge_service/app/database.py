"""
SQLAlchemy 引擎 & Session 工厂
"""

import logging

from sqlalchemy import create_engine, text, inspect
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import sessionmaker, declarative_base, Session
from typing import Generator

from .config import get_settings

settings = get_settings()

engine = create_engine(
    settings.DATABASE_URL,
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,
    pool_recycle=3600,
    echo=settings.DEBUG,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()
logger = logging.getLogger(__name__)


def get_db() -> Generator[Session, None, None]:
    """FastAPI 依赖注入 —— 每个请求独立 Session"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def create_tables():
    """根据 ORM 模型创建所有表（首次启动时调用）"""
    from . import models  # noqa: F401  确保所有模型已注册
    try:
        Base.metadata.create_all(bind=engine)
    except SQLAlchemyError as exc:
        # 生产环境常见为业务账号无 DDL 权限，此时允许服务继续启动，
        # 由管理员通过迁移脚本建表。
        logger.warning("自动建表失败，跳过 create_all（请手动执行迁移脚本）: %s", exc)

    # 增量迁移：为已有表添加新列（create_all 只建新表，不加列）
    _migrate_add_columns()


def _migrate_add_columns():
    """检查并添加缺失的列（安全幂等操作）"""
    migrations = [
        ("user_profiles", "level", "VARCHAR(64) NULL COMMENT '级别'"),
    ]
    insp = inspect(engine)
    for table, column, col_def in migrations:
        if not insp.has_table(table):
            continue
        existing = {c["name"] for c in insp.get_columns(table)}
        if column in existing:
            continue
        try:
            with engine.begin() as conn:
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {column} {col_def}"))
            logger.info("迁移：已为 %s 添加列 %s", table, column)
        except SQLAlchemyError as exc:
            logger.warning("迁移：为 %s 添加列 %s 失败（需管理员手动执行）: %s", table, column, exc)
