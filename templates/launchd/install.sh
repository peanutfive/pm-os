#!/usr/bin/env bash
# install.sh — 把 pm-os 里的 launchd 任务装进 ~/Library/LaunchAgents 并加载
#
# 用法：
#   bash ~/developer/pm-os/templates/launchd/install.sh
#
# 卸载见 README.md。

set -e

PLIST_SRC="$(cd "$(dirname "$0")" && pwd)/workspace-health.plist"
PLIST_NAME="com.klara.workspace-health.plist"
TARGET="$HOME/Library/LaunchAgents/$PLIST_NAME"

if [ ! -f "$PLIST_SRC" ]; then
  echo "✗ 找不到源 plist：$PLIST_SRC"
  exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents"
mkdir -p "$HOME/Library/Logs"

# 如果已安装，先 unload 旧的
if [ -f "$TARGET" ]; then
  echo "发现已存在的 $PLIST_NAME，先 unload 旧版本..."
  launchctl unload "$TARGET" 2>/dev/null || true
fi

cp "$PLIST_SRC" "$TARGET"
echo "✓ 已复制 plist 到 $TARGET"

# -w 参数：写入 disabled key，保证重启后仍然启用
launchctl load -w "$TARGET"
echo "✓ 已加载任务"
echo ""

echo "=== 校验 ==="
if launchctl list | grep -q "com.klara.workspace-health"; then
  echo "✓ 任务已注册："
  launchctl list | grep "com.klara.workspace-health" | awk '{printf "  PID=%s  ExitCode=%s  Label=%s\n", $1, $2, $3}'
  echo ""
  echo "下次运行时间：每月 1 号 10:00（错过会在电脑醒来后补跑）"
  echo "日志位置：$HOME/Library/Logs/workspace-health.log"
  echo ""
  echo "立即手动触发一次测试："
  echo "  launchctl start com.klara.workspace-health"
  echo "  # 然后 cat ~/Library/Logs/workspace-health.log 看结果"
else
  echo "✗ 任务没有注册成功，检查："
  echo "  1. plist 语法：plutil -lint $TARGET"
  echo "  2. launchctl 输出：launchctl error \$?"
fi
