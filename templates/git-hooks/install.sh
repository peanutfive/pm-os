#!/usr/bin/env bash
# install.sh — 把 pm-os 提供的 git hooks 接入当前仓库
#
# 用法：在目标仓库根目录里跑
#   bash ~/developer/pm-os/templates/git-hooks/install.sh
#
# 原理：设置 git config --local core.hooksPath，指向 pm-os 下的 hooks
#       目录。pm-os 里的 hooks 更新后，所有接入过的仓库下次提交自动用
#       最新版本。
#
# 卸载：git config --unset core.hooksPath

set -e

HOOKS_DIR="$(cd "$(dirname "$0")/hooks" && pwd)"
TARGET_REPO="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"

if [ -z "$TARGET_REPO" ]; then
  echo "✗ 当前目录不在 git 仓库内。请 cd 到要安装 hooks 的仓库根目录再跑。"
  exit 1
fi

# 确保 hook 可执行
chmod +x "$HOOKS_DIR"/*

# 设置 core.hooksPath
git -C "$TARGET_REPO" config --local core.hooksPath "$HOOKS_DIR"

echo "✓ 已为 $(basename "$TARGET_REPO") 接入 pm-os git hooks"
echo "  hooks 路径: $HOOKS_DIR"
echo ""
echo "生效的 hooks:"
ls "$HOOKS_DIR" | sed 's/^/  · /'
echo ""
echo "如需卸载：git -C '$TARGET_REPO' config --unset core.hooksPath"
echo "如需临时绕过单次 pre-commit：git commit --no-verify（不推荐）"
