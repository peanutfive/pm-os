# pm-os launchd 任务

macOS 原生的定时任务配置（对应 Linux 的 cron / systemd timer），比 cron 更适合笔记本场景，因为电脑睡眠/关机错过的触发**会在醒来后自动补跑**。

## 当前任务

| 文件 | Label | 调度 | 作用 |
|---|---|---|---|
| `workspace-health.plist` | `com.klara.workspace-health` | 每月 1 号 10:00 | 跑 `scripts/workspace-health-check.sh`，体检 `~/developer/` 下所有仓库 |

## 安装 / 更新

```bash
bash ~/developer/pm-os/templates/launchd/install.sh
```

会做三件事：把 plist 拷到 `~/Library/LaunchAgents/`、load 起来、打印验证。
重复跑这个脚本就是"更新"。

## 常用命令

```bash
# 查看所有已加载的 LaunchAgent（看你的是否在列）
launchctl list | grep com.klara

# 立即手动触发一次（不等到 1 号，用来测试）
launchctl start com.klara.workspace-health

# 看日志
tail -f ~/Library/Logs/workspace-health.log
tail -f ~/Library/Logs/workspace-health.err   # 如果出错

# 卸载（停止 + 不再随登录加载）
launchctl unload ~/Library/LaunchAgents/com.klara.workspace-health.plist

# 彻底删除
rm ~/Library/LaunchAgents/com.klara.workspace-health.plist

# 检查 plist 语法（改完 plist 后装回去前先这步）
plutil -lint ~/developer/pm-os/templates/launchd/workspace-health.plist
```

## 加新的 launchd 任务

1. 复制 `workspace-health.plist` 起名，比如 `daily-backup.plist`
2. 改里面的 `Label`（必须和文件名一致，约定 `com.klara.<任务名>`）
3. 改 `ProgramArguments` 指向要跑的脚本
4. 改 `StartCalendarInterval` 调度，或换成别的触发方式（见下）
5. 改 `StandardOutPath` / `StandardErrorPath` 避免和其他任务日志冲突
6. 复制到 `~/Library/LaunchAgents/` 并 `launchctl load -w` 装上

## 调度方式 cheat sheet

### 按日历时间（最常用）

```xml
<!-- 每天 09:00 -->
<key>StartCalendarInterval</key>
<dict>
    <key>Hour</key><integer>9</integer>
    <key>Minute</key><integer>0</integer>
</dict>

<!-- 每月 1 号 10:00 -->
<key>StartCalendarInterval</key>
<dict>
    <key>Day</key><integer>1</integer>
    <key>Hour</key><integer>10</integer>
    <key>Minute</key><integer>0</integer>
</dict>

<!-- 每周一早上 08:30（Weekday: 0=Sun, 1=Mon, ...） -->
<key>StartCalendarInterval</key>
<dict>
    <key>Weekday</key><integer>1</integer>
    <key>Hour</key><integer>8</integer>
    <key>Minute</key><integer>30</integer>
</dict>

<!-- 多个时间：数组嵌 dict -->
<key>StartCalendarInterval</key>
<array>
    <dict><key>Hour</key><integer>9</integer><key>Minute</key><integer>0</integer></dict>
    <dict><key>Hour</key><integer>18</integer><key>Minute</key><integer>0</integer></dict>
</array>
```

### 固定间隔

```xml
<!-- 每 3600 秒跑一次（1 小时） -->
<key>StartInterval</key>
<integer>3600</integer>
```

### 加载时立即跑 + 重启后跑

```xml
<key>RunAtLoad</key>
<true/>
```

### 文件/目录变化触发（有趣但易误触发）

```xml
<key>WatchPaths</key>
<array>
    <string>/path/to/watched/dir</string>
</array>
```

## 常见坑

1. **`~` 不展开**：plist 里必须用 `/Users/xxx/...` 绝对路径，不能写 `~/...`。
2. **PATH 默认很窄**：不设 `EnvironmentVariables/PATH`，脚本里调 `git` / `gh` / `brew` 都会找不到。本模板已预设 `/opt/homebrew/bin:/usr/local/bin:...`。
3. **`KeepAlive=true` 是坑**：字面意思"进程退出就重启"，不是"守活着"。定时任务一定用 `false`。
4. **改了 plist 要重 load**：`launchctl unload` 再 `load`，不然内存里还是旧的。
5. **macOS 14+ 可能弹权限**：第一次 load 时系统会让你授权"允许 launchd 完全访问磁盘"之类的。同意即可，只问一次。

## cron vs launchd 选哪个

- 笔记本 + 需要"错过要补跑" → **launchd**
- 24/7 开机的服务器 / 云机 → **cron** 依然足够
- macOS 上想用更现代的方式 → **launchd**
- 想让配置直接跟着脚本走 PR review → cron 一行，launchd 一份 XML，看团队习惯
