# AGENTS.md — 给 AI 协作者的指南

这个文档是给 AI agent（Cursor / Claude Code / Codex 等）在本仓库工作时读的说明。

---

## 仓库身份

- **仓库名**：{{PROJECT_NAME}}
- **默认分支**：`main`
- **远端**：`{{GITHUB_URL}}`
- **这是独立仓库**，不是其他项目的子目录。新文件一律创建在本仓库根下，除非明确说明。

## 你需要知道的

<!-- 项目的核心上下文，AI 应该先读这一段再动手 -->

- 定位：...
- 目标用户：...
- 技术栈：...
- 重要约束（如"不用 LLM 实时生成剧情"、"vendor/ 不入 git" 等）：...

## 工作约定

### Commit

- 使用 conventional 前缀：`feat:` / `fix:` / `chore:` / `docs:` / `refactor:` / `test:`
- 标题 ≤ 72 字符；正文用于解释**为什么**这么改
- AI 生成的 commit 末尾加一行 `Made-with:` 或 `Co-Authored-By:` trailer

### 分支

- 小改动直接在 `main`
- 较大功能走 `feat/<topic>` 分支 + PR
- AI agent 临时分支用 `claude/...` 或 `codex/...` 前缀

### 不允许的事

- 把本仓库的文件创建到父目录或其他仓库里
- 从不相关的仓库克隆后当"脚手架"用（会污染 remote / history）
- 把 `node_modules/` / `.venv/` / `xcuserdata/` / `.DS_Store` 之类加入提交

### 提交前自检

- `.gitignore` 是否仍然覆盖当前所有应忽略的目录
- 是否有 `TODO` / `WIP` / `临时` 字样遗留
- 是否有未用完的调试代码 / `console.log` / `print()`

## 本项目的"AI 辅助边界"

<!-- 明确哪些事交给 AI，哪些事要人工决定 -->

- ✅ AI 可以做：...
- ⚠️ 需要人工评审：...
- ❌ 不要让 AI 做：...
