# 做完 1 年 Temu AI PM + 8 个月独立产品后，我写了一套 AI 协作工作系统

> 作者：陈楷（[cn17k2@gmail.com](mailto:cn17k2@gmail.com)）
> 写于 2026 年 4 月，一场"自己当自己的审计"之后

---

## 一、事故现场

2026 年 4 月 20 号傍晚，我在整理本地代码目录。

`git log --stat` 跑下去，看到一条让我愣住的 commit：

```
commit e42e93d  (2026-03-27)
Author: peanutfive <cn17k2@gmail.com>
    Add Oasis website baseline project files

    Capture the current Oasis Next.js website scaffold...
    Made-with: Cursor

 developer/oasis/.eslintrc.json
 developer/oasis/OPTIMIZATION_PLAN.md
 developer/oasis/WEBSITE_SPEC.md
 developer/oasis/next.config.ts
 developer/oasis/package.json
 ... （35 个文件，+9761 行）
```

这是一个 Cursor 生成的 commit。**但它的仓库位置错了** —— 这批 Oasis（我的 AI 音频简报产品）的脚手架文件被提交进了 `memory_site`（我的一个个人纪念站）的 git 历史。两个项目毫无关系。

**Cursor 没意识到它在错的仓库里 `git add`。它只知道"这里有个 `.git`，那就提交吧"。**

我以为这是孤立事件，继续扫下去，不到一小时列出了更多：

| 问题 | 情况 |
|---|---|
| `~/developer/oasis/` 这个目录的 `origin` 指向 `peanutfive/our-galaxy.git` | 我用"克隆 memory_site"的方式起了 Oasis 项目，remote 一直没改。工作了好几个月才发现 |
| 本地存在 **3 份 Oasis** | `memory_site/developer/oasis/`、`~/developer/oasis/`（坏克隆）、`~/developer/oasis-github/`（真正的仓库） |
| `klara/pm-os/` 是 `pm-os/` 的过时克隆 | 文件 100% 一样，旧了 20 天 |
| `klara/trinity-relit/` 和 `Trinity1986Infocom/` 都是同一个游戏项目 | 一份多了游戏资源，一份多了 LICENSE commit |
| `stock-monitor/.venv/` 占 **288 MB** | Python 虚拟环境，虽然 gitignored 但没人清 |
| `Jumpstar_Project_Export` 追踪了 2 份 `.DS_Store` | macOS 系统垃圾永远留在了 git 历史里 |
| 有一个分支直接叫 `commit` | 操作失误产物，但一直没删 |

这些都不是 bug、不是线上事故、不会被监控告警。**它们只是慢慢让你的本地环境变得无法解释。**

我把这个现象命名为**"AI 协作的物理副作用"**。

---

## 二、四类问题

扫完一遍之后，我把所有毛病归纳成四个家族：

### 1. 起点错位（Birth Errors）
- 新项目文件被创建在了无关仓库里
- 克隆一个无关仓库当脚手架，`origin` 永远错
- `git init` 在了错的目录层级

### 2. 提交时脏东西混入（Commit Pollution）
- `.DS_Store`
- `node_modules/`、`.venv/`
- 单文件超 10 MB（git lfs 都没来得及考虑）
- `.env` 里的 API key
- 非 conventional commit message（不是大问题，但读历史时累）

### 3. 长期堆积（Drift）
- 重复克隆（多份同一个远端）
- 未推送的本地分支、遗忘的 stash
- 超大 `node_modules/` 放着不清
- 嵌套的 `.git` 目录（可能是误提交的子项目）

### 4. 发现问题 ≠ 解决问题
- 上面这些东西"发现一次"容易
- **让它们不再累积**才是真问题

AI 协作让前三类问题发生的频率上升（因为 Cursor / Codex / Claude Code 各有各的边界假设），但每一个都**不是 AI 的错**，是**我没有给 AI 划清边界**。

---

## 三、反推出四件套

每个家族反推出一个工具，都落在我那个叫 `pm-os` 的 repo 里。

### 🧰 防起点错位：`new-project` skill

Cursor / Claude / 任何 AI 工具起新项目时，强制走 5 步：

1. 是**独立项目**，还是**现有项目的子模块**？
   （独立 → 继续；子模块 → 退出流程，别在这里搞 `git init`）
2. 目标位置：**不能被任何祖先 git 仓库实际追踪**
   （被 `.gitignore` ignore 了没事 —— 这是常见的"`~/` 是 dotfiles 仓库 + 在 `~/developer/` 下建独立项目"的合法场景）
3. 按技术栈选 `.gitignore` 模板（已写 node / python / swift-ios / static 四份）
4. `git init -b main` → 写 README → 跑脚手架 → 首次 commit → `gh repo create`
5. sanity check 清单逐项核对：`remote` 是否正确、`log` 是否只有自己的 commit、`status` 是否干净

这个 skill 是一个 Cursor / Claude Code 可读取的 `.mdc` 文件 + 模板库。AI 触发关键词（"新建项目"、"scaffold"）就自动走完。

**它的存在理由就是防住那次 Cursor 误提交。**

### 🧰 防提交脏东西：Git hooks 三件套

用 `git config --local core.hooksPath` 接入 pm-os 下的 hooks（pm-os 里改一次，所有接入仓库下次提交自动用新版）：

- **pre-commit**：阻断 `.DS_Store` / `node_modules/` / `.venv/` / `DerivedData/` / 单文件 > 10 MB / `.env`（非 `.example`）/ diff 行匹配 `sk-*` `AKIA*` `ghp_*` 等密钥模式
- **commit-msg**：警告（不阻断）非 conventional 前缀 / 超 72 字符
- **post-commit**：打印本次 stats，警告"在 main 上一次改了 > 10 个文件"（提醒用 feature 分支）

写完第二天，这套 hook 就在**自己的 commit 上触发了警告**（commit msg 73 字符、在 main 一次 15 文件），完整自证设计是活的。

### 🧰 找堆积：`workspace-health-check.sh`

POSIX / bash 3.2 兼容的扫描脚本（macOS 自带 bash 就能跑），检查 `~/developer/` 下所有 git 仓库的 8 项健康度：

1. 重复克隆
2. 目录名 vs remote 名不匹配
3. 追踪的 `.DS_Store`
4. 追踪的大依赖目录
5. 超大 `node_modules` / `.venv` / `DerivedData`
6. 嵌套 git 仓库
7. orphan 分支 / stash 堆积
8. 追踪的 `.env`（智能排除 `.example` / `.sample`）

退出码：0（干净）/ 1（警告）/ 2（严重），方便接入 CI / 告警 / 邮件推送。

### 🧰 自动化调度：launchd 每月 1 号跑

```xml
<key>StartCalendarInterval</key>
<dict>
    <key>Day</key><integer>1</integer>
    <key>Hour</key><integer>10</integer>
    <key>Minute</key><integer>0</integer>
</dict>
```

为什么不用 cron？**cron 在 Mac 睡眠/关机时错过就错过。launchd 醒来会补跑。** 对笔记本用户来说这不是小差别，是"每月审计能不能 1 月不漏"的关键。

`launchctl load -w` 装上后，每月 1 号 10 点不管机器是否开机，`workspace-health-check.sh` 都会跑一次，结果写到 `~/Library/Logs/workspace-health.log`。

---

## 四、我真正想说的

行业在讨论 AI 协作时，谈的都是：

- Prompt 工程
- Agent 能力
- 上下文管理
- 多模型协同
- RAG / 工具调用

**很少有人谈 AI 协作留给你工作区的物理后果。**

就好像设计师只谈配色和构图，却不管墙面是否脱漆、地面是否平整、电线是否走对方向 —— 那是施工质量。

AI 协作也有它的"施工质量"：

- **文件该在哪就在哪**，不在无关仓库里游荡
- **提交干净**，不带运行时垃圾和系统垃圾
- **重复的东西有人清**
- **问题会被定期发现**，不是"3 个月后整理一次才突然爆发"

pm-os 里这四件套（new-project skill / git hooks / health check / launchd），本质上是一个关于"AI 协作施工质量"的**个人工具集**。

---

## 五、为什么 pm-os 不是"又一个 AI PM 模板"

GitHub 上的 AI PM 工具包很多。绝大多数长这样：

```
├── README.md           （方法论陈述）
├── templates/
│   ├── prd-template.md
│   ├── user-story-template.md
│   └── ...
└── examples/
```

用的人自己脑补"我可以用这个"。但很少真的持续用。

pm-os 长得不一样的地方：

1. **每个工具有具体事故作为起源**
   - `new-project` skill 的存在理由是那次 Cursor 误提交
   - `git hooks` 的存在理由是那些 `.DS_Store` 和我差点提交上去的 `.env`
   - `launchd` 的存在理由是"我知道自己不会主动去跑月检"

2. **方法论 ↔ 实战双向闭环**
   - pm-os 的 PRD / 需求文档模板被我用来产出 Oasis（一个跨端 AI 产品）的实际文档
   - Oasis 开发中的踩坑反过来让 pm-os 增加 new-project / hooks / launchd 等工具
   - 不是理论先行，是**问题驱动迭代**

3. **覆盖完整生命周期**
   - 不是一个模板库
   - 是**起步（防错）→ 提交（防脏）→ 长期（防漂）**三个时点都有工具的系统

---

## 六、这些原则不只属于我

pm-os 的具体形式（`com.klara.*` 的 launchd Label、Cursor Skills 的 frontmatter）是我的。但**背后的原则可迁移**：

> **新项目启动前先走 5 项校验**
> **每次提交前 hooks 扫三件事：脏文件 / 大文件 / 密钥**
> **每月扫一次自己的工作区**
> **把踩过的坑规则化**

如果你也在用 AI 工具做产品工作，这篇文章可以当成一个参照 checklist。pm-os 目前是私有的（GitHub 上同类太多，公开未必有竞争力），但**它的组织方式、每个工具的来源、触发条件、阈值选择** —— 这些都在这篇文章里写清楚了。

---

## 七、收尾

我离开 Temu 8 个月了。这 8 个月独立做 Oasis 和 pm-os。两者其实是同一件事的两面：

- **Oasis** 证明"我能 ship 复杂 AI 产品"
- **pm-os** 证明"我 ship 产品的过程本身经得起拆解"

第二件比第一件稀缺 —— 绝大多数人只能证明其中一件。

**找下一份工作时（AI 创业公司方向），我打算两个一起带。** 如果这篇文章里的哪个细节让你想到了"我公司也有类似问题"，或者你想聊聊"AI 协作的边界该怎么划"，欢迎联系我。

---

**作者**：陈楷
**在做**：[Oasis](https://github.com/peanutfive/oasis) — AI 音频简报跨端产品（Web 三语 + 原生 iOS）
**在找**：AI 创业公司 0→1 产品负责人 / 核心 PM
**邮箱**：cn17k2@gmail.com
