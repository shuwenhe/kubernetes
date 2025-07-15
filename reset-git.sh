#!/bin/bash
# reset_git.sh - 删除 Git 历史并重新推送干净版本

set -e

# 检查是否提供远程仓库地址
if [ -z "$1" ]; then
    echo "❌ 用法: ./reset_git.sh <remote_repo_url>"
    echo "例如: ./reset_git.sh https://github.com/yourname/yourrepo.git"
    exit 1
fi

REMOTE_URL="$1"

echo "🧩 设置 Git 用户信息..."
git config --global user.email "1201220707@pku.edu.cn"
git config --global user.name "shuwen"

echo "🧹 删除旧的 .git 目录..."
rm -rf .git

echo "🆕 初始化新的 Git 仓库..."
git init

# 添加当前目录为安全目录，防止 "dubious ownership" 报错
git config --global --add safe.directory "$(pwd)"

echo "📂 添加所有文件到新仓库..."
git add .

echo "✅ 提交新版本..."
git commit -m "Initial commit (history removed)"

echo "🌐 添加远程仓库地址: $REMOTE_URL"
git remote add origin "$REMOTE_URL"

# 设置默认分支为 main（可选）
git branch -M main

echo "🚀 强制推送到远程仓库..."
git push -f origin main

echo "✅ 完成！当前目录已被上传为一个无历史的新 Git 仓库。"

