"""
FastAPI 应用入口 —— 路由注册、生命周期管理、表创建
"""

import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .config import get_settings
from .database import create_tables
from .api.documents import router as documents_router
from .api.knowledge_points import router as knowledge_points_router
from .api.questions import router as questions_router
from .api.recommendations import router as recommendations_router
from .api.tags import router as tags_router
from .services.minio_service import minio_service

settings = get_settings()

# ── 日志配置 ──────────────────────────────────────────────
logging.basicConfig(
    level=logging.DEBUG if settings.DEBUG else logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


# ── 生命周期 ──────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用启动 / 关闭生命周期"""
    # ── 启动 ──────────────────────────────────────────
    logger.info(f"启动 {settings.APP_NAME} v{settings.APP_VERSION}")

    # 创建数据库表
    logger.info("初始化数据库表...")
    create_tables()

    # 初始化 MinIO bucket
    logger.info("初始化 MinIO bucket...")
    try:
        minio_service.ensure_bucket()
    except Exception as e:
        logger.warning(f"MinIO bucket 初始化失败（服务可能未启动）: {e}")

    # 预加载 jieba 分词（避免首次调用 1-2s 延迟）
    logger.info("预加载 jieba 分词词典...")
    try:
        import jieba
        import jieba.analyse
        jieba.initialize()
        # 将数据库中已有的标签名加入自定义词典，提升领域分词精度
        from .database import SessionLocal
        from .models.tag import Tag
        _db = SessionLocal()
        try:
            tags = _db.query(Tag.tag_name).filter(Tag.is_enabled == 1).all()
            for (name,) in tags:
                if name and len(name) >= 2:
                    jieba.add_word(name, freq=50000, tag="nz")  # nz=专有名词，高词频确保不被切分
                    jieba.analyse.default_tfidf.idf_freq[name] = 15.0  # 提高 TF-IDF 权重
            logger.info("jieba 已加载 %d 个领域标签词", len(tags))

        finally:
            # 初始化 NLP 标签匹配缓存（复用同一个 session，独立 try 避免影响 jieba）
            try:
                from .services.tag_matcher import refresh_tag_cache
                refresh_tag_cache(_db)
            except Exception as e:
                logger.warning("NLP 标签匹配缓存初始化跳过: %s", e)
            _db.close()
    except Exception as e:
        logger.warning("jieba 预加载跳过: %s", e)

    logger.info("应用启动完成")
    yield

    # ── 关闭 ──────────────────────────────────────────
    logger.info("应用关闭")


# ── 创建 FastAPI 应用 ─────────────────────────────────────

app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="考试平台 AI 知识处理服务 —— 文档上传、解析、知识点抽取与 RAG 知识库同步",
    lifespan=lifespan,
)

# ── CORS 中间件 ───────────────────────────────────────────

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── 挂载静态文件 ──────────────────────────────────────────

# 获取静态文件目录路径
static_dir = Path(__file__).parent.parent / "static"
if static_dir.exists():
    app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")
    logger.info(f"静态文件目录已挂载: {static_dir}")

# ── 注册路由 ──────────────────────────────────────────────

app.include_router(documents_router, prefix="/api/v1")
app.include_router(knowledge_points_router, prefix="/api/v1")
app.include_router(questions_router, prefix="/api/v1")
app.include_router(recommendations_router, prefix="/api/v1")
app.include_router(tags_router, prefix="/api/v1")


# ── 健康检查 ──────────────────────────────────────────────

@app.get("/health", tags=["系统"])
async def health_check():
    """服务健康检查"""
    return {
        "status": "ok",
        "service": settings.APP_NAME,
        "version": settings.APP_VERSION,
    }


@app.get("/", tags=["系统"])
async def root():
    """根路径"""
    return {
        "service": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "docs": "/docs",
        "upload": "/static/upload.html",
        "list": "/static/list.html",
        "generate": "/static/generate.html",
        "practice": "/static/practice.html",
        "recommend_admin": "/static/recommend-admin.html",
        "tags": "/static/tags.html",
    }
