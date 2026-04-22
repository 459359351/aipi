# 考试平台 AI 知识处理服务

基于 FastAPI 的文档上传、解析、知识点抽取与 RAG 知识库同步服务。

> 详细设计与实现说明见 [docs/SERVICE_DESIGN.md](docs/SERVICE_DESIGN.md)

## 技术栈

| 组件       | 技术                          |
| ---------- | ----------------------------- |
| Web 框架   | FastAPI                       |
| ORM        | SQLAlchemy 2.0                |
| 数据库     | MySQL 8.0                     |
| 对象存储   | MinIO                         |
| LLM        | 阿里云 DashScope (Qwen)      |
| RAG 知识库 | Dify Dataset API              |
| 任务处理   | FastAPI BackgroundTasks       |

## 服务架构说明

| 服务 | 作用 | 是否必须 |
|------|------|----------|
| **FastAPI 后端** | 提供 API + 前端静态页面 | 必须 |
| **MySQL** | 数据库 | 必须 |
| **MinIO** | 对象存储，存放上传文件 | 上传文档时必须 |
| **Dify** | RAG 知识库 | 可选，同步知识点时需要 |

**前端**：已集成在 FastAPI 中，访问 `/static/index.html` 即可，无需单独启动。

## 项目结构

```
knowledge_service/
├── app/
│   ├── main.py                  # FastAPI 应用入口
│   ├── config.py                # 配置管理
│   ├── database.py              # SQLAlchemy 引擎 & Session
│   ├── models/                  # ORM 模型
│   │   ├── document.py          # 文档表
│   │   ├── knowledge_point.py   # 知识点表
│   │   ├── tag.py               # 标签表
│   │   └── knowledge_tag_rel.py # 知识点-标签关联表
│   ├── schemas/                 # Pydantic 请求/响应模型
│   ├── api/                     # API 路由
│   │   ├── documents.py         # 文档上传 & 查询
│   │   └── knowledge_points.py  # 知识点查询
│   ├── services/                # 业务服务层
│   │   ├── document_service.py  # 文档业务逻辑
│   │   ├── minio_service.py     # MinIO 操作
│   │   ├── parser_service.py    # 文档解析 (PDF/Word/TXT)
│   │   ├── knowledge_extractor.py # LLM 知识点抽取
│   │   └── dify_service.py      # Dify 知识库 API
│   └── tasks/
│       └── document_tasks.py    # 后台异步任务
├── static/                      # 前端调试页面
│   ├── index.html               # 首页
│   ├── upload.html              # 上传页
│   ├── list.html                # 文档列表
│   └── detail.html              # 文档详情
├── requirements.txt
├── .env.example
├── start.sh                     # 一键启动脚本
└── README.md
```

## 快速开始

### 1. 安装依赖

```bash
cd knowledge_service
pip install -r requirements.txt
```

### 2. 配置环境变量

```bash
cp .env.example .env
# 编辑 .env 文件，填入实际的 MySQL、MinIO、Dify、DashScope 配置
```

### 3. 启动 FastAPI 服务（必须）

```bash
# 1. 激活 conda 环境（如使用 conda）
conda activate aipi

# 2. 进入项目目录
cd knowledge_service

# 3. 启动服务（使用 python -m 确保使用正确环境的 Python）
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

或使用一键启动脚本：

```bash
./start.sh
```

启动成功后访问：
- **首页**：http://localhost:8000/static/index.html
- **上传页**：http://localhost:8000/static/upload.html
- **文档列表**：http://localhost:8000/static/list.html
- **API 文档**：http://localhost:8000/docs

### 4. 启动 MinIO（上传文档时需要）

**方式 A：Docker（推荐）**

```bash
docker run -d \
  --name minio \
  -p 9000:9000 \
  -p 9001:9001 \
  -e MINIO_ROOT_USER=minioadmin \
  -e MINIO_ROOT_PASSWORD=minioadmin \
  quay.io/minio/minio server /data --console-address ":9001"
```

访问 MinIO 控制台：http://localhost:9001

**方式 B：Homebrew（macOS）**

```bash
brew install minio/stable/minio
mkdir -p ~/minio-data
minio server ~/minio-data
```

MinIO 默认端口 9000，`.env` 中已配置 `MINIO_ENDPOINT=127.0.0.1:9000`。

**未启动 MinIO 时**：FastAPI 可正常启动，首页、列表、详情页均可访问，但**上传文档会失败**。

## API 端点

| 方法   | 路径                                            | 说明               |
| ------ | ----------------------------------------------- | ------------------ |
| POST   | `/api/v1/documents/upload`                      | 上传文档           |
| GET    | `/api/v1/documents/{document_id}`               | 查询文档详情       |
| POST   | `/api/v1/documents/{document_id}/reparse`       | 重新解析文档       |
| GET    | `/api/v1/knowledge-points/by-document/{doc_id}` | 查询文档的知识点   |
| GET    | `/api/v1/knowledge-points/{kp_id}`              | 查询单个知识点     |
| GET    | `/health`                                       | 健康检查           |

## 公司作用域权限契约

所有返回文档、知识点、题目、出题任务、审题数据、推荐结果的接口，现在都要求显式传入下面两个查询参数：

- `scope_role`: `global_admin` 或 `branch_admin`
- `scope_company_id`: 调用方所属公司/分公司 ID

写接口还需要遵守下面的归属规则：

- 新建文档时必须显式传 `target_company_ids`
- `target_company_ids` 表示该条数据最终归属于哪些公司
- 总公司管理员可以传多个公司 ID
- 分公司管理员只能传自己的 `scope_company_id`
- 文档派生的知识点、出题任务、AI 题目自动继承文档归属，不允许单独修改题目归属
- `document_id is null` 的人工题通过 `question_company_scope_rel` 维护直接归属

默认可见性：

- 总公司管理员可见所有数据，包括尚未绑定任何公司归属的历史数据
- 分公司管理员只能看到命中本公司归属的数据
- 未绑定公司归属的历史数据，对分公司管理员不可见

本地调试页面默认会从 URL 查询参数或 `localStorage` 读取：

- `scope_role`
- `scope_company_id`
- `target_company_ids`（逗号分隔，仅上传页用于默认填充）

未提供时，静态页会默认用 `global_admin / GLOBAL` 作为演示值。

## 核心流程

```
上传文档 → 保存元数据(MySQL) → 存储文件(MinIO) → 触发后台任务
    ↓
后台任务: 下载文件 → 解析文本 → LLM抽取知识点 → 写入MySQL → 同步Dify知识库
    ↓
标记完成 / 标记失败(支持重试)
```

## 数据表

- **documents** — 文档元数据（名称、类型、领域、版本、文件信息、状态等）
- **knowledge_points** — 知识点（标题、内容、摘要、重要度、Dify 同步状态）
- **tags** — 标签字典（标签名、分类）
- **knowledge_tag_rel** — 知识点与标签的多对多关联

## 前置依赖

- Python 3.10+
- MySQL 8.0+
- MinIO（对象存储服务）
- Dify（RAG 知识库平台，可选）
- 阿里云 DashScope API Key（用于 Qwen LLM）

## 常见问题

### 1. 打不开 http://localhost:8000/static/index.html

- **确认 FastAPI 是否在运行**：终端应看到 `Uvicorn running on http://0.0.0.0:8000`
- **检查端口占用**：`lsof -i :8000` 查看 8000 端口
- **尝试其他地址**：http://127.0.0.1:8000/static/index.html

### 2. 上传文档失败

- 确认 MinIO 已启动（`curl http://localhost:9000/minio/health/live` 应返回 200）
- 检查 `.env` 中 `MINIO_ENDPOINT` 是否为 `127.0.0.1:9000`

### 3. 文档列表为空

- 当前列表页通过遍历 ID 1-100 查询，若没有文档会显示空
- 先上传一个文档再刷新列表
