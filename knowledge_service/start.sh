#!/bin/bash
# 知识处理服务 - 一键启动脚本

set -e
cd "$(dirname "$0")"

echo "=========================================="
echo "  知识处理服务 - 启动脚本"
echo "=========================================="
echo ""

# 检查 conda 环境
if ! command -v conda &> /dev/null; then
    echo "❌ 未找到 conda，请先安装 Miniconda/Anaconda"
    exit 1
fi

# 激活 conda 环境
echo "📦 激活 conda 环境 aipi..."
eval "$(conda shell.bash hook 2>/dev/null || conda shell.zsh hook 2>/dev/null)"
conda activate aipi

# 检查 Python
if ! python -c "import fastapi" 2>/dev/null; then
    echo "❌ 依赖未安装，请先执行: pip install -r requirements.txt"
    exit 1
fi

echo ""
echo "🚀 启动 FastAPI 服务..."
echo "   访问地址: http://localhost:8000/static/index.html"
echo "   API 文档: http://localhost:8000/docs"
echo ""
echo "按 Ctrl+C 停止服务"
echo "=========================================="

python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
