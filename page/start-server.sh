#!/bin/bash

# 区块链笔记管理系统 - 快速启动脚本

echo "🚀 启动区块链笔记管理系统..."
echo ""

# 检查 Python 是否安装
if command -v python3 &> /dev/null; then
    echo "✅ 使用 Python3 启动 HTTP 服务器..."
    echo "📡 服务地址: http://localhost:8000"
    echo "⚠️  请在浏览器中访问上述地址"
    echo "💡 按 Ctrl+C 停止服务器"
    echo ""
    python3 -m http.server 8000
elif command -v python &> /dev/null; then
    echo "✅ 使用 Python 启动 HTTP 服务器..."
    echo "📡 服务地址: http://localhost:8000"
    echo "⚠️  请在浏览器中访问上述地址"
    echo "💡 按 Ctrl+C 停止服务器"
    echo ""
    python -m SimpleHTTPServer 8000
else
    echo "❌ 未找到 Python"
    echo ""
    echo "请安装 Python 或使用以下替代方案："
    echo "  1. 使用 Node.js: npx http-server -p 8000"
    echo "  2. 使用 VS Code Live Server 扩展"
    echo ""
fi
