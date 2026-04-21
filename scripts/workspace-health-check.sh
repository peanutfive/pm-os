#!/usr/bin/env bash
# workspace-health-check.sh
#
# 定期扫描 ~/developer/ 下的 git 仓库，找出 AI 协作容易留下的物理副作用：
# - 重复 / 误克隆仓库（两处目录 remote 指向同一个 GitHub repo）
# - 远端指向错误（目录名和 remote repo 名对不上）
# - 被追踪的 .DS_Store / node_modules / .venv
# - 巨大的依赖目录（node_modules > 500M / .venv > 200M）长期占磁盘
# - 长期未推送的本地分支（orphan 分支、stash 堆积）
# - 嵌套 git 仓库（一个 git 仓库的工作区里又有 .git —— 可能是误提交子项目）
# - 常见敏感文件（.env* 被 track）
#
# 建议：每月跑一次。
# 用法：bash ~/developer/pm-os/scripts/workspace-health-check.sh [ROOT]
#   ROOT 默认为 ~/developer
#
# 兼容 macOS 自带 bash 3.2 及以上。

ROOT="${1:-$HOME/developer}"
YELLOW=$'\033[1;33m'
RED=$'\033[1;31m'
GREEN=$'\033[1;32m'
DIM=$'\033[0;90m'
RESET=$'\033[0m'

WARN_COUNT=0
CRIT_COUNT=0

section() {
  echo ""
  echo "═══════════════════════════════════════════════"
  echo "  $1"
  echo "═══════════════════════════════════════════════"
}
warn()  { echo "${YELLOW}⚠️  $*${RESET}"; WARN_COUNT=$((WARN_COUNT+1)); }
crit()  { echo "${RED}🚨 $*${RESET}"; CRIT_COUNT=$((CRIT_COUNT+1)); }
ok()    { echo "${GREEN}✓${RESET} $*"; }
info()  { echo "${DIM}  $*${RESET}"; }

if [ ! -d "$ROOT" ]; then
  echo "扫描根目录不存在：$ROOT"
  exit 1
fi

echo "🔍 扫描根目录：$ROOT"
echo "    （执行期间可能需要 5-30 秒）"

TMPDIR_HC=$(mktemp -d)
trap 'rm -rf "$TMPDIR_HC"' EXIT

REPOS_FILE="$TMPDIR_HC/repos.txt"
find "$ROOT" -maxdepth 4 -name ".git" -type d 2>/dev/null | while read -r gitdir; do
  dirname "$gitdir"
done | sort -u > "$REPOS_FILE"
REPO_COUNT=$(wc -l < "$REPOS_FILE" | tr -d ' ')

section "0. 概览"
echo "发现 $REPO_COUNT 个 git 仓库"

# ─────────────────────────────────────────────
section "1. 重复仓库（两处目录 remote 指向同一 GitHub repo）"
# ─────────────────────────────────────────────

REMOTE_MAP="$TMPDIR_HC/remote-map.txt"
> "$REMOTE_MAP"
while IFS= read -r repo; do
  [ -z "$repo" ] && continue
  url=$(git -C "$repo" remote get-url origin 2>/dev/null || echo "")
  [ -z "$url" ] && continue
  # normalize: drop https:// / git@ prefix and .git suffix
  key=$(echo "$url" | sed -E 's|https?://[^/]+/||; s|\.git$||; s|git@[^:]+:||')
  echo "$key|$repo" >> "$REMOTE_MAP"
done < "$REPOS_FILE"

DUP_URLS="$TMPDIR_HC/dup-urls.txt"
awk -F'|' '{print $1}' "$REMOTE_MAP" | sort | uniq -c | awk '$1 > 1 {print $2}' > "$DUP_URLS"

if [ -s "$DUP_URLS" ]; then
  while IFS= read -r dup_url; do
    crit "同一远端被多处本地克隆：$dup_url"
    grep "^$dup_url|" "$REMOTE_MAP" | awk -F'|' '{print $2}' | while read -r d; do
      info "→ $d"
    done
  done < "$DUP_URLS"
else
  ok "没有重复克隆"
fi

# ─────────────────────────────────────────────
section "2. 远端指向错误（目录名 vs remote repo 名不匹配）"
# ─────────────────────────────────────────────

mismatch=0
while IFS= read -r repo; do
  [ -z "$repo" ] && continue
  url=$(git -C "$repo" remote get-url origin 2>/dev/null || echo "")
  [ -z "$url" ] && continue
  remote_name=$(echo "$url" | sed -E 's|.*/||; s|\.git$||')
  dir_name=$(basename "$repo")
  nd=$(echo "$dir_name" | tr '[:upper:]_' '[:lower:]-')
  nr=$(echo "$remote_name" | tr '[:upper:]_' '[:lower:]-')
  if [ "$nd" != "$nr" ] && [ "${nd#*$nr}" = "$nd" ] && [ "${nr#*$nd}" = "$nr" ]; then
    mismatch=1
    warn "目录 $dir_name 的 remote 名是 $remote_name"
    info "→ $repo"
    info "→ remote: $url"
  fi
done < "$REPOS_FILE"
[ "$mismatch" -eq 0 ] && ok "所有仓库的目录名与 remote 基本一致"

# ─────────────────────────────────────────────
section "3. 被追踪的 .DS_Store / 系统垃圾"
# ─────────────────────────────────────────────

ds_found=0
while IFS= read -r repo; do
  [ -z "$repo" ] && continue
  n=$(git -C "$repo" ls-files 2>/dev/null | grep -c '\.DS_Store$')
  if [ "$n" -gt 0 ]; then
    ds_found=1
    warn "$repo 追踪了 $n 个 .DS_Store"
    info "修法: cd '$repo' && git rm --cached '*.DS_Store' && git commit -m 'chore: untrack .DS_Store'"
  fi
done < "$REPOS_FILE"
[ "$ds_found" -eq 0 ] && ok "没有追踪的 .DS_Store"

# ─────────────────────────────────────────────
section "4. 被追踪的大体积依赖目录（不该入 git）"
# ─────────────────────────────────────────────

big_found=0
while IFS= read -r repo; do
  [ -z "$repo" ] && continue
  for dep in node_modules .venv venv env __pycache__ DerivedData .build; do
    tracked=$(git -C "$repo" ls-files 2>/dev/null | grep -c "^$dep/")
    if [ "$tracked" -gt 0 ]; then
      big_found=1
      crit "$repo 追踪了 $tracked 个 $dep/ 下的文件"
      info "修法: cd '$repo' && git rm -r --cached $dep/ && 在 .gitignore 加上 $dep/"
    fi
  done
done < "$REPOS_FILE"
[ "$big_found" -eq 0 ] && ok "没有被追踪的大型依赖目录"

# ─────────────────────────────────────────────
section "5. 磁盘占用：巨大的非 git 目录（可安全删除后重建）"
# ─────────────────────────────────────────────

echo "  （规则：node_modules > 500M 或 .venv > 200M 或 DerivedData > 300M 时提醒）"
disk_found=0
while IFS= read -r repo; do
  [ -z "$repo" ] && continue
  for pair in "node_modules:500" ".venv:200" "DerivedData:300"; do
    name="${pair%:*}"
    th="${pair##*:}"
    path="$repo/$name"
    if [ -d "$path" ]; then
      size=$(du -sm "$path" 2>/dev/null | awk '{print $1}')
      if [ -n "$size" ] && [ "$size" -gt "$th" ]; then
        disk_found=1
        warn "$(basename "$repo")/$name 占用 ${size}M"
        info "若近期不用可删：rm -rf '$path'（需要时可重建）"
      fi
    fi
  done
done < "$REPOS_FILE"
[ "$disk_found" -eq 0 ] && ok "没有超限的依赖目录"

# ─────────────────────────────────────────────
section "6. 嵌套 git 仓库（一个工作区里藏了另一个 .git）"
# ─────────────────────────────────────────────

nested_found=0
while IFS= read -r repo; do
  [ -z "$repo" ] && continue
  find "$repo" -maxdepth 4 -name ".git" -type d 2>/dev/null | while read -r g; do
    [ "$g" = "$repo/.git" ] && continue
    rel=${g#$repo/}
    echo "NESTED|$repo|$rel"
  done
done < "$REPOS_FILE" > "$TMPDIR_HC/nested.txt"

if [ -s "$TMPDIR_HC/nested.txt" ]; then
  while IFS='|' read -r _ repo rel; do
    warn "$repo 内嵌套 git 仓库：$rel"
    info "确认这是有意的子仓库（submodule / 独立 fork），或是误提交的副项目"
    nested_found=1
  done < "$TMPDIR_HC/nested.txt"
fi
[ "$nested_found" -eq 0 ] && ok "没有意料外的嵌套 git 仓库"

# ─────────────────────────────────────────────
section "7. 本地分支无上游 / stash 堆积"
# ─────────────────────────────────────────────

branch_found=0
while IFS= read -r repo; do
  [ -z "$repo" ] && continue
  orphan_cnt=$(git -C "$repo" for-each-ref --format='%(refname:short) %(upstream)' refs/heads 2>/dev/null | awk '$2=="" {c++} END {print c+0}')
  if [ "$orphan_cnt" -gt 2 ]; then
    branch_found=1
    warn "$(basename "$repo") 有 $orphan_cnt 个本地分支无上游（可能是堆积的 AI agent 临时分支）"
    info "→ $repo"
  fi
  stash_cnt=$(git -C "$repo" stash list 2>/dev/null | wc -l | tr -d ' ')
  if [ "$stash_cnt" -gt 3 ]; then
    branch_found=1
    warn "$(basename "$repo") 有 $stash_cnt 个 stash（可能已遗忘）"
    info "查看: cd '$repo' && git stash list"
  fi
done < "$REPOS_FILE"
[ "$branch_found" -eq 0 ] && ok "分支和 stash 没有明显堆积"

# ─────────────────────────────────────────────
section "8. 敏感文件被追踪"
# ─────────────────────────────────────────────

secret_found=0
while IFS= read -r repo; do
  [ -z "$repo" ] && continue
  # 追踪 .env 或 .env.xxx，但排除常规模板如 .env.example / .sample / .template
  envs=$(git -C "$repo" ls-files 2>/dev/null \
           | grep -E '^\.env(\..+)?$' \
           | grep -vE '\.(example|sample|template)$' || true)
  if [ -n "$envs" ]; then
    secret_found=1
    crit "$(basename "$repo") 追踪了 .env 文件（可能含密钥）"
    echo "$envs" | while read -r f; do info "→ $f"; done
    info "修法: git rm --cached <file> + 加入 .gitignore + 轮换受影响的密钥"
  fi
done < "$REPOS_FILE"
[ "$secret_found" -eq 0 ] && ok "没有追踪的 .env 文件"

# ─────────────────────────────────────────────
section "总结"
# ─────────────────────────────────────────────
echo "  严重问题: $CRIT_COUNT"
echo "  警告    : $WARN_COUNT"
echo ""
if [ "$CRIT_COUNT" -eq 0 ] && [ "$WARN_COUNT" -eq 0 ]; then
  echo "${GREEN}🎉 工作区干净，无需行动${RESET}"
  exit 0
elif [ "$CRIT_COUNT" -gt 0 ]; then
  echo "${RED}需要尽快处理 $CRIT_COUNT 个严重问题${RESET}"
  exit 2
else
  echo "${YELLOW}有 $WARN_COUNT 个警告可以有空时处理${RESET}"
  exit 1
fi
