#!/bin/bash
# ========================================
#  Hexo 博客编辑器 - 图形化界面
#  双击运行修改文章
# ========================================

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

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
  set chosen to choose from list postList with title \"✏️ 修改文章\" with prompt \"请选择要修改的文章：\"
  if chosen is false then return \"\"
  return item 1 of chosen
" 2>/dev/null)

if [ -z "$SELECTED" ]; then
  echo "已取消"
  exit 0
fi

FILEPATH="$POSTS_DIR/${SELECTED}.md"

# ── 读取当前信息 ──
CURRENT_TITLE=$(head -20 "$FILEPATH" | grep "^title:" | sed 's/title: //' | xargs)
CURRENT_TAG=$(head -20 "$FILEPATH" | grep -A 5 "^tags:" | grep "^- " | head -1 | sed 's/- //' | xargs)
CURRENT_CAT=$(head -20 "$FILEPATH" | grep -A 5 "^categories:" | grep "^- " | head -1 | sed 's/- //' | xargs)

# ── 选择操作 ──
ACTION=$(osascript -e "
  set theActions to {\"修改内容\", \"修改分类\", \"修改标签\", \"全部修改\"}
  set chosen to choose from list theActions with title \"✏️ 选择操作\" with prompt \"当前文章：$CURRENT_TITLE
分类：$CURRENT_CAT | 标签：$CURRENT_TAG\" default items {\"修改内容\"}
  if chosen is false then return \"\"
  return item 1 of chosen
" 2>/dev/null)

if [ -z "$ACTION" ]; then
  echo "已取消"
  exit 0
fi

# ── 修改分类 ──
if [[ "$ACTION" == "修改分类" || "$ACTION" == "全部修改" ]]; then
  NEW_CAT=$(osascript -e '
    set theCats to {"长文", "短文"}
    set chosenCat to choose from list theCats with title "📂 修改分类" with prompt "请选择分类：" default items {"'"$CURRENT_CAT"'"}
    if chosenCat is false then return ""
    return item 1 of chosenCat
  ' 2>/dev/null)

  if [ -n "$NEW_CAT" ] && [ "$NEW_CAT" != "$CURRENT_CAT" ]; then
    perl -i -0pe "s/categories:\n(\s*-\s*).*(\n)/categories:\n  - $NEW_CAT\n/" "$FILEPATH"
  fi
fi

# ── 修改标签 ──
if [[ "$ACTION" == "修改标签" || "$ACTION" == "全部修改" ]]; then
  NEW_TAG=$(osascript -e "
    set theTags to {\"随笔\", \"技术\", \"生活\", \"读书笔记\", \"朋友圈\", \"其他\"}
    set chosenTag to choose from list theTags with title \"🏷️ 修改标签\" with prompt \"当前标签：$CURRENT_TAG\n\n请选择标签：\"
    if chosenTag is false then return \"\"
    return item 1 of chosenTag
  " 2>/dev/null)

  if [ -n "$NEW_TAG" ] && [ "$NEW_TAG" != "$CURRENT_TAG" ]; then
    perl -i -0pe "s/tags:\n(\s*-\s*).*(\n)/tags:\n  - $NEW_TAG\n/" "$FILEPATH"
  fi
fi

# ── 修改内容 ──
if [[ "$ACTION" == "修改内容" || "$ACTION" == "全部修改" ]]; then
  open -e "$FILEPATH"
  
  osascript -e "
    display dialog \"文章已在文本编辑器中打开。

修改完成后，点击「继续」即可自动发布。\" with title \"✏️ 正在编辑\" buttons {\"取消\", \"继续\"} default button \"继续\"" 2>/dev/null

  if [ $? -ne 0 ]; then
    echo "已取消"
    exit 0
  fi
fi

# ── 确认发布 ──
NEW_TITLE_FINAL=$(head -20 "$FILEPATH" | grep "^title:" | sed 's/title: //' | xargs)
CONFIRM=$(osascript -e "
  display dialog \"已修改文章「${NEW_TITLE_FINAL}」

确定要重新发布吗？\" with title \"✅ 确认发布\" buttons {\"取消\", \"发布\"} default button \"发布\"" 2>/dev/null)

if [[ "$CONFIRM" != *"发布"* ]]; then
  echo "已取消发布"
  exit 0
fi

echo "🔨 正在生成..."
npx hexo generate 2>&1 || { osascript -e 'display dialog "生成失败。" with title "❌ 错误" buttons {"OK"} with icon stop'; exit 1; }

echo "🚀 正在部署..."
npx hexo deploy 2>&1 || { osascript -e 'display dialog "发布失败。" with title "❌ 错误" buttons {"OK"} with icon stop'; exit 1; }

osascript -e "
  display dialog \"🎉 修改发布成功！

文章「${NEW_TITLE_FINAL}」已更新
https://laurentdiao.github.io\" with title \"✅ 成功\" buttons {\"OK\"} default button \"OK\""
