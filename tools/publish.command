#!/bin/bash
# ========================================
#  Hexo 博客发布器 - 图形化界面
#  双击运行
# ========================================

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

# ── 选择分类 ──
CATEGORY=$(osascript -e '
  set theCats to {"长文", "短文"}
  set chosenCat to choose from list theCats with title "📂 选择分类" with prompt "请选择文章类型：" default items {"长文"}
  if chosenCat is false then return ""
  return item 1 of chosenCat
' 2>/dev/null)

if [ -z "$CATEGORY" ]; then
  echo "已取消"
  exit 0
fi

# ── 输入标题 ──
TITLE=$(osascript -e '
  tell application "System Events"
    display dialog "请输入文章标题：" default answer "" with title "📝 写新文章"
    return text returned of result
  end tell' 2>/dev/null)

if [ -z "$TITLE" ]; then
  echo "已取消"
  exit 0
fi

# 生成文件名
FILENAME=$(echo "$TITLE" | sed 's/[\/:*?"<>|]/_/g')
FILEPATH="source/_posts/${FILENAME}.md"

if [ -f "$FILEPATH" ]; then
  osascript -e 'display dialog "该标题的文章已存在！" with title "⚠️ 错误" buttons {"OK"} default button "OK" with icon stop'
  exit 1
fi

# ── 输入内容 ──
CONTENT=$(osascript -e '
  tell application "System Events"
    display dialog "请输入正文内容（Markdown 格式）：" default answer "" with title "✍️ 正文内容"
    return text returned of result
  end tell' 2>/dev/null)

if [ -z "$CONTENT" ]; then
  echo "已取消"
  exit 0
fi

# ── 选择标签 ──
TAG=$(osascript -e '
  set theTags to {"随笔", "技术", "生活", "读书笔记", "朋友圈", "其他"}
  set chosenTag to choose from list theTags with title "🏷️ 选择标签" with prompt "请选择一个标签：" default items {"随笔"}
  if chosenTag is false then return ""
  return item 1 of chosenTag
' 2>/dev/null)

if [ -z "$TAG" ]; then
  TAG="随笔"
fi

# ── 确认发布 ──
CONFIRM=$(osascript -e "
  display dialog \"即将发布文章：

分类：$CATEGORY
标题：$TITLE
标签：$TAG

内容预览：
$(echo "$CONTENT" | head -c 100)...

确定要发布吗？\" with title \"✅ 确认发布\" buttons {\"取消\", \"发布\"} default button \"发布\"" 2>/dev/null)

if [[ "$CONFIRM" != *"发布"* ]]; then
  echo "已取消"
  exit 0
fi

# ── 创建文章 ──
DATE=$(date "+%Y-%m-%d %H:%M:%S")
cat > "$FILEPATH" << EOF
---
title: $TITLE
date: $DATE
tags:
  - $TAG
categories:
  - $CATEGORY
---

$CONTENT
EOF

echo "✅ 文章已创建: $FILEPATH"

# ── 生成 + 部署 ──
echo "🔨 正在生成静态文件..."
npx hexo generate 2>&1

if [ $? -ne 0 ]; then
  osascript -e 'display dialog "生成静态文件失败，请检查终端输出。" with title "❌ 错误" buttons {"OK"} default button "OK" with icon stop'
  exit 1
fi

echo "🚀 正在部署到 GitHub Pages..."
npx hexo deploy 2>&1

if [ $? -ne 0 ]; then
  osascript -e 'display dialog "发布失败，请检查终端输出。" with title "❌ 错误" buttons {"OK"} default button "OK" with icon stop'
  exit 1
fi

osascript -e "
  display dialog \"🎉 发布成功！

「${TITLE}」（${CATEGORY}）已上线
https://laurentdiao.github.io\" with title \"✅ 发布成功\" buttons {\"OK\"} default button \"OK\""

echo ""
echo "🎉 发布完成！https://laurentdiao.github.io"
