#!/bin/bash
# ========================================
#  修改 About Me 页面 - 图形化界面
# ========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

ABOUT_FILE="source/about/index.md"

# ── 打开文件编辑 ──
open -e "$ABOUT_FILE"

osascript -e "
  display dialog \"about 页面已在文本编辑器中打开。

修改完成后，点击「发布」即可自动更新网站。\" with title \"✏️ 修改 About Me\" buttons {\"取消\", \"发布\"} default button \"发布\"" 2>/dev/null

if [ $? -ne 0 ] || [ "$(osascript -e 'button returned of result' 2>/dev/null)" == "取消" ]; then
  echo "已取消"
  exit 0
fi

# ── 生成 + 部署 ──
echo "🔨 正在生成..."
npx hexo generate 2>&1 || { osascript -e 'display dialog "生成失败" with title "❌ 错误" buttons {"OK"} with icon stop'; exit 1; }

echo "🚀 正在部署..."
npx hexo deploy 2>&1 || { osascript -e 'display dialog "部署失败" with title "❌ 错误" buttons {"OK"} with icon stop'; exit 1; }

osascript -e 'display dialog "🎉 about me 已更新上线！" with title "✅ 成功" buttons {"OK"}'
