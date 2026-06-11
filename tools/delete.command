#!/bin/bash
# ========================================
#  Hexo 博客删除器 - 图形化界面
#  双击运行删除文章
# ========================================

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

# ── 获取文章列表 ──
POSTS_DIR="source/_posts"
POSTS=()
while IFS= read -r file; do
  name=$(basename "$file" .md)
  POSTS+=("$name")
done < <(ls "$POSTS_DIR"/*.md 2>/dev/null)

if [ ${#POSTS[@]} -eq 0 ]; then
  osascript -e 'display dialog "没有找到任何文章。" with title "📭 无文章" buttons {"OK"} default button "OK"'
  exit 0
fi

# ── 转换为 AppleScript list ──
APPLESCRIPT_LIST="{"
for i in "${!POSTS[@]}"; do
  APPLESCRIPT_LIST+="\"${POSTS[$i]}\""
  if [ $i -lt $((${#POSTS[@]} - 1)) ]; then
    APPLESCRIPT_LIST+=", "
  fi
done
APPLESCRIPT_LIST+="}"

# ── 选择文章 ──
SELECTED=$(osascript -e "
  set postList to $APPLESCRIPT_LIST
  set chosen to choose from list postList with title \"🗑️ 删除文章\" with prompt \"请选择要删除的文章：\"
  if chosen is false then return \"\"
  return item 1 of chosen
" 2>/dev/null)

if [ -z "$SELECTED" ]; then
  echo "已取消"
  exit 0
fi

FILEPATH="$POSTS_DIR/${SELECTED}.md"

# ── 二次确认 ──
CONFIRM=$(osascript -e "
  display dialog \"⚠️ 确定要删除文章「${SELECTED}」吗？

此操作不可撤销！\" with title \"🗑️ 确认删除\" buttons {\"取消\", \"删除\"} default button \"取消\" with icon stop" 2>/dev/null)

if [[ "$CONFIRM" != *"删除"* ]]; then
  echo "已取消"
  exit 0
fi

# ── 执行删除 ──
rm "$FILEPATH"
echo "🗑️ 已删除: $FILEPATH"

# ── 生成 + 部署 ──
echo "🔨 正在重新生成..."
npx hexo generate 2>&1

if [ $? -ne 0 ]; then
  osascript -e 'display dialog "生成失败。" with title "❌ 错误" buttons {"OK"} default button "OK" with icon stop'
  exit 1
fi

echo "🚀 正在部署..."
npx hexo deploy 2>&1

if [ $? -ne 0 ]; then
  osascript -e 'display dialog "发布失败。" with title "❌ 错误" buttons {"OK"} default button "OK" with icon stop'
  exit 1
fi

osascript -e "
  display dialog \"🗑️ 删除成功！

文章「${SELECTED}」已从网站移除
https://laurentdiao.github.io\" with title \"✅ 成功\" buttons {\"OK\"} default button \"OK\""
