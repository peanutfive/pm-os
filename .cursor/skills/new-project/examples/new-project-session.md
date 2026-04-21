# 示例会话：一次"做得对"的新项目创建

这是 `new-project` skill 被正确触发后，AI 与用户之间应有的对话形态。用来作为 AI 行为的参考样本。

---

**用户**：帮我起一个新项目，做个记录每天小习惯的小工具，Next.js + Tailwind。

**AI**：
> 在开始之前先走一遍项目起点校验（防止今天又出 `developer/oasis/` 那类问题）：
>
> 1. **独立项目还是子模块？** —— 听你描述像独立新项目。
> 2. **放在哪？** 默认建议 `~/developer/habit-log/`。这个路径下我先检查一下：
>    - 目录不存在 ✓
>    - 父目录（`~/developer/`）不在任何 git 仓库里 ✓
>    - 可以用。
> 3. **技术栈**：Next.js → 走 `gitignore-node.txt` 模板
> 4. **是否建 GitHub 远端？**（private / public？仓库名确认是 `habit-log`？）

**用户**：是的，GitHub 私有，仓库名就 habit-log。

**AI** 执行：

```bash
# 1. 创建目录并进入
mkdir -p ~/developer/habit-log
cd ~/developer/habit-log

# 2. 先写 .gitignore（在 git init 之前！）
cat > .gitignore <<'EOF'
# 从 templates/gitignore-node.txt 粘贴
...
EOF

# 3. init + 默认分支 main
git init -b main

# 4. 写 README.md（从 README-seed.md 替换 {{PROJECT_NAME}}）
# 5. 写 AGENTS.md（从 AGENTS-seed.md 填充项目上下文）

# 6. 跑 Next.js 脚手架
npx create-next-app@latest . --typescript --tailwind --app --eslint --yes

# 7. 核查：status 里没有 node_modules、没有 .DS_Store、没有 .next
git status --short | grep -E 'node_modules|\.DS_Store|\.next' && echo "⚠️ STOP" || echo "✓ clean"

# 8. 首次 commit
git add .
git commit -m "feat: initialize habit-log project

- Next.js 16 + TypeScript + Tailwind baseline
- Standard .gitignore for Node/Next stack
- README and AGENTS docs seeded

Made-with: Cursor"

# 9. 建 GitHub 远端并推送
gh repo create habit-log --private --source=. --remote=origin --push
```

---

## AI 该做的 sanity check（跑完上面之后）

```bash
# 清单逐项核对
git remote -v                     # URL 必须是 github.com/.../habit-log.git
git log --oneline                 # 只有 "feat: initialize habit-log project" 一条
git status                        # clean
git branch --show-current         # main
ls .gitignore README.md           # 存在
```

每项都 ✓ 才算创建完成。

---

## 如果 AI 自己发现流程走歪了

立刻 `cd` 回到安全位置，用下面任一方式补救：

- **如果在错的目录 init 了**：`rm -rf .git` → 回到正确目录重来
- **如果 clone 了无关仓库**：`rm -rf` 整个目录重来，不要在错仓库里续命
- **如果 remote 指错了**：`git remote remove origin` 后重新 `gh repo create`

**不要**悄悄继续工作然后希望以后再修 —— 那正是今天所有问题的来源。
