---
name: new-project
description: 新起一个代码项目时的仓库初始化校验流程。当用户说"新建项目"、"开一个新项目"、"start a new project"、"scaffold 一个...项目"、"从零建一个..."、或让 AI 开始写一个 package.json / Package.swift / pyproject.toml 等项目起点文件时强制触发。职责：确保新项目放在正确的目录、使用正确的 git 初始化方式、选用匹配技术栈的 .gitignore 模板，防止把新项目误塞进已有仓库。
---

# New Project — 项目起点校验

## 为什么存在这个 skill

AI 工具（Cursor / Claude Code / Codex）新起项目时最常见的两个错误：

1. **把新项目文件创建在当前打开的仓库里**，并 `git add` 到那个仓库的提交历史 —— 实际案例：Cursor 把 Oasis 的 Next.js 脚手架提交进了 `memory_site/developer/oasis/`，污染了 memorial site 的 git 历史。
2. **克隆一个已有仓库作为起点**（因为那个仓库里有类似的代码可参考），结果新项目的 `remote origin` 错指向原仓库，历史和身份混在一起 —— 实际案例：`~/developer/oasis/` 的 remote 一直指向 `github.com/peanutfive/our-galaxy.git`（memory_site 的远端），导致"改了几个月发现自己其实没有一个真正的 Oasis 仓库"。

这个 skill 的核心任务：**在新项目第一个文件落地之前，强制走完一套校验流程**。

---

## 触发时必须做的动作

### 第 0 步（最高优先级）：STOP，确认"新项目 vs 现有项目扩展"

在创建任何文件之前，先回答一个问题：

> 这是一个**独立的新项目**（要有自己的 git 仓库、自己的远端、自己的部署），还是**现有项目的一个子模块 / 子目录**（属于已有仓库的一部分）？

**如果是现有项目的子模块** → 不需要这个 skill。退出流程，直接在现有仓库里工作。

**如果是独立的新项目** → 继续下面的流程，**任何时候都不要把文件写到当前已存在的 git 仓库的工作区**。

---

### 第 1 步：确定项目位置

问用户明确的目录路径。路径必须满足：

- 目标路径**不能**被任何祖先 git 仓库**实际追踪**（被 `.gitignore` 忽略则没事 —— 这是常见的"`~/` 是 dotfiles 仓库 + 在 `~/developer/` 下建独立项目"的合法场景）
- 推荐默认放在 `~/developer/<project-name>/`，除非用户指定其他路径
- 如果路径已存在且非空，**停下来让用户确认**（是覆盖、重命名，还是选别的目录）

校验逻辑分三档（**判定关键不是"祖先有 .git"，而是"祖先 git 仓库会不会管这个路径"**）：

| 祖先仓库对目标路径的态度 | 判定 | 行动 |
|---|---|---|
| `git check-ignore` 命中（被忽略） | ✓ **安全** | 直接 init 新仓库 |
| `git ls-files` 命中（已追踪） | 🚨 **冲突** | 换位置，否则会撞到祖先仓库的 history |
| 既未 ignore 也未 track（dangling） | ⚠️ **要先把目标加进祖先仓库的 `.gitignore`** | 否则未来在这里改的文件会被祖先仓库 `git status` 视为 untracked，污染状态 |

```bash
# 校验命令示例
TARGET=~/developer/my-new-project
PARENT=$(dirname "$TARGET")

# 1. 目标已存在 → 让用户决定
if [ -e "$TARGET" ]; then
  echo "⚠️ 目录已存在，停下来找用户确认（覆盖 / 重命名 / 换位置）"
fi

# 2. 检查祖先 git 仓库对目标路径的态度
ANCESTOR=$(git -C "$PARENT" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$ANCESTOR" ]; then
  REL=${TARGET#$ANCESTOR/}
  if git -C "$ANCESTOR" check-ignore -q "$REL" 2>/dev/null; then
    echo "✓ 祖先仓库 $ANCESTOR 已忽略 '$REL'，可以安全 init 独立仓库"
  elif git -C "$ANCESTOR" ls-files --error-unmatch "$REL" >/dev/null 2>&1; then
    echo "🚨 '$REL' 已被祖先仓库 $ANCESTOR 追踪 —— 真正的冲突，换位置或先从祖先移除"
    exit 1
  else
    echo "⚠️  祖先仓库 $ANCESTOR 存在，但 '$REL' 既未 ignore 也未 track（dangling）"
    echo "    建议：先在 $ANCESTOR/.gitignore 加上 '$REL/'，避免它把你的新仓库视为 untracked"
  fi
fi
```

---

### 第 2 步：识别技术栈，选对应的 .gitignore 模板

根据用户描述的项目类型，选一个或组合模板：

| 项目类型 | 模板文件 |
|---|---|
| Node.js / Next.js / React / TypeScript | `templates/gitignore-node.txt` |
| Python | `templates/gitignore-python.txt` |
| Swift / iOS / macOS / Xcode | `templates/gitignore-swift-ios.txt` |
| 纯静态网站（HTML / CSS / JS） | `templates/gitignore-static.txt` |
| 多栈混合（如 Web + iOS） | 多个模板**合并**，人工去重 |

**每个模板都已经包含** `templates/gitignore-common.txt` 的内容（macOS / 编辑器垃圾），不需要额外引入。

---

### 第 3 步：初始化仓库（按这个顺序，不要颠倒）

```bash
# 1. 创建目录并进入
mkdir -p ~/developer/<project-name>
cd ~/developer/<project-name>

# 2. 先写 .gitignore（一定在 git init 之前，避免第一次 commit 就把垃圾 track 进来）
cat > .gitignore <<'EOF'
<从模板粘贴>
EOF

# 3. 初始化 git（默认分支设置为 main）
git init -b main

# 4. 写 README.md（从 templates/README-seed.md 改）
# 5. （可选）写 AGENTS.md（从 templates/AGENTS-seed.md 改）—— 如果这个项目会有 AI 协作

# 6. 首次 commit
git add .
git commit -m "feat: initialize <project-name> project"
```

**关键纪律**：
- `git init` 必须在**新目录内**执行。如果不小心在父目录 init 了，立刻 `rm -rf .git` 重来
- 第一次 `git add` 前跑一遍 `git status`，确认没有怪东西（比如从父目录继承下来的文件）被加进来
- `.DS_Store`、`node_modules/`、`.venv/`、`xcuserdata/`、`dist/`、`.env` 等**绝对不能**出现在第一次 commit 里

---

### 第 4 步：创建 GitHub 远端（如果用户确认要托管）

```bash
# 用 gh 创建远端仓库并推送
gh repo create <project-name> --private --source=. --remote=origin --push
```

**检查**：
- 确认 `git remote -v` 显示的 URL 是**新仓库**，不是借用其他仓库的 URL
- 如果 `gh auth status` 提示登录的账号不对，先 `gh auth switch` 再建仓库

---

### 第 5 步：第一次 commit 之后的 sanity check

跑一遍这个清单，每项都要 ✓：

- [ ] `git remote -v` 显示的 URL 对应这个新项目（不是借来的旧仓库）
- [ ] `git log --oneline` 只有刚刚的 "initialize" 一条记录（不是带了别人 10 个 commit）
- [ ] `git status` 干净（没有 `.DS_Store`、`node_modules/` 之类应该被忽略却显示为 untracked 的文件）
- [ ] `git branch` 当前在 `main`
- [ ] 项目根目录有 `.gitignore`、`README.md`（至少这两个）

如果有任何一项不过，**停下来让用户决定**是修正还是重来 —— 不要自行扩大改动。

---

## 反模式清单（出现任一，立即停下报警）

| 反模式 | 修法 |
|---|---|
| 在现有仓库**实际追踪的**子目录里 `git init` 新项目（祖先 `git ls-files` 命中） | 把文件移到一个明确被祖先 ignore 的位置（如 `~/developer/<new-name>/`，前提是 `~/.gitignore` 已忽略 `developer/`）再 `git init` |
| 在现有仓库的"dangling 子目录"里 `git init`（既非 tracked 也非 ignored） | 先在祖先仓库的 `.gitignore` 加上对应路径，再 `git init`，避免祖先仓库未来把这块视为 untracked |
| `git clone` 一个无关仓库当脚手架 | `rm -rf <clone>` → `git init` 全新仓库，需要代码从源仓库手动复制相关文件（不要继承 `.git`） |
| 新仓库的 `origin` 指向别的项目的 URL | `git remote set-url origin <新 URL>` 或 `git remote remove origin` 重来 |
| 第一次 commit 就有 node_modules / .DS_Store / .venv | `git rm -r --cached <path>` → 补齐 `.gitignore` → 新 commit |
| 忘记设 `gh` 当前账号，仓库建到错的 GitHub 账号下 | 在 GitHub 上手动转移，或删掉重新以正确账号建 |

---

## 成功路径示例

参考 `examples/new-project-session.md` 看一个完整的"用户说想做个新东西 → AI 走完校验 → 提交第一个 commit"的对话。

---

## 何时**不**触发这个 skill

- 用户只是要**改现有项目的配置**（加个依赖、改 README）
- 用户明说"在 XXX 仓库下新建一个子模块"（例如 monorepo 内加 package）
- 用户在做**一次性脚本**或临时 `/tmp/` 文件，不会变成长期项目
