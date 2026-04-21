# pm-os git hooks

一套防止 AI 协作留下"物理副作用"的 git hooks，放在 pm-os 里统一维护。

## 包含的 hooks

| Hook | 触发时机 | 行为 |
|---|---|---|
| `pre-commit` | 提交前 | **阻断**含 `.DS_Store` / `node_modules/` / `.venv/` / 单文件 > 10MB / `.env` / 疑似密钥模式的提交 |
| `commit-msg` | 写完 commit 消息时 | **警告**非 conventional 前缀 / 过短 / 过长的首行（不阻断） |
| `post-commit` | 提交完成后 | **提示**本次 stats；若含 > 1MB 文件或一次改 > 30 文件，给出警告 |

## 安装

在你想接入的仓库根目录里：

```bash
bash ~/developer/pm-os/templates/git-hooks/install.sh
```

这一步会把 `git config --local core.hooksPath` 设成 `pm-os/templates/git-hooks/hooks`。
以后 pm-os 里 hooks 改了，该仓库下次提交自动用新版本（无需再装）。

## 卸载

```bash
git config --unset core.hooksPath
```

## 常见问题

**Q：我有合法理由要提交 `.DS_Store` / 大文件 / `.env`，怎么办？**
A：尽量不要这样。真的需要：
- 大文件 → 用 git-lfs
- `.env` → 通常能转成 `.env.example` + 在 README 写怎么填
- `.DS_Store` → 基本没有合法理由

实在要绕过单次：`git commit --no-verify`。但这会同时跳过所有检查，包括敏感密钥扫描 —— **慎用**。

**Q：误报了怎么办？**
A：改 `pm-os/templates/git-hooks/hooks/<hook>` 里的规则，然后提交到 pm-os。
所有接入的仓库下次自动用新规则。

**Q：hooks 会不会拖慢提交？**
A：pre-commit 在单个中型仓库里通常 <1 秒。真正慢的点是密钥正则扫描，
如果你的 diff 经常非常大，可以把 hook 里 `secret_patterns` 那块临时注释掉。

**Q：团队项目里别人没装 hooks 怎么办？**
A：`core.hooksPath` 是 `--local` 配置，只影响你自己这份 clone。如果希望全队
用同一套，把 hooks 目录提交进仓库（例如放在 `.githooks/`），然后每人跑
`git config core.hooksPath .githooks`。本脚手架目的是保护自己，不强加团队。
