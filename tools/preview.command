#!/bin/bash
# ========================================
#  Local preview - pull comments and serve Hexo
# ========================================

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR" || exit 1

echo "📥 Pulling latest comments and site files..."
git pull --ff-only origin main

if [ $? -ne 0 ]; then
  osascript -e 'display dialog "git pull 失败。可能是本地有未提交修改，或远端分支更新冲突。请打开终端查看输出。" with title "❌ 本地预览失败" buttons {"OK"} default button "OK" with icon stop'
  exit 1
fi

echo ""
echo "Hexo preview is starting at:"
echo "http://127.0.0.1:4000"
echo ""
echo "Keep this window open while previewing."
echo "Press Control-C in this window to stop the server."
echo ""

if curl -fsS "http://127.0.0.1:4000" >/dev/null 2>&1; then
  echo "✅ Hexo server is already running."
  echo "🌐 Opening local preview..."
  open "http://127.0.0.1:4000"
  exit 0
fi

cleanup() {
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null
  fi
}
trap cleanup EXIT INT TERM

npx hexo server -p 4000 &
SERVER_PID=$!

echo "⏳ Waiting for Hexo server..."
for i in {1..40}; do
  if curl -fsS "http://127.0.0.1:4000" >/dev/null 2>&1; then
    echo "🌐 Opening local preview..."
    open "http://127.0.0.1:4000"
    wait "$SERVER_PID"
    exit $?
  fi

  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    break
  fi

  sleep 0.5
done

osascript -e 'display dialog "Hexo server 启动失败。可能是 4000 端口被占用，或依赖未安装。请打开终端查看输出。" with title "❌ 本地预览失败" buttons {"OK"} default button "OK" with icon stop'
exit 1
