# psmux：原生 Windows 终端复用器

psmux 直接使用 Windows ConPTY，不需要 WSL、Cygwin、Git Bash 或其他 Shell。所有 pane
继续运行 PowerShell 7。配置文件是 `~/.psmux.conf`，语法兼容 tmux。请使用 `mux` 或
`mux-dev` 启动；它们会在连接和创建 server 时显式加载配置，避免 psmux 重启后回到默认键位。

## 开始使用

```powershell
# 创建或进入 main session
mux

# 指定名称
mux backend

# 自动创建左侧 Neovim、右侧 Amp 的开发布局
mux-dev project

# 查看已有 session
mux-ls
```

离开但保留后台程序：按 `Ctrl+A`，松开后按 `d`。重新执行 `mux 名称` 即可恢复。

## 快捷键总览

前缀键是 `Ctrl+A`。下表中的 `Prefix x` 表示先按 `Ctrl+A`，全部松开，再按 `x`，
而不是同时按三个键。`C-方向键` 表示第二步按 `Ctrl+方向键`，`M-方向键` 表示
`Alt+方向键`。按 `Ctrl+A` 两次可将原始 `Ctrl+A` 发送给 PowerShell、Neovim 或 Amp。

最高频操作不需要 Prefix：直接按 `Alt+方向键` 切换 Pane，增加 `Shift` 后调整大小。
Windows Terminal 已释放这些按键，由 psmux 统一管理空间导航。

### Session

| 按键或命令 | 用途 |
|---|---|
| `Prefix d` | Detach：离开但保留当前 Session 和其中的程序 |
| `Prefix s` | 打开 Session/Window/Pane 树；方向键选择，`Enter` 切换，`q` 退出 |
| `Prefix (` / `Prefix )` | 切换到上一个 / 下一个 Session |
| `Prefix $` | 重命名当前 Session |
| `Prefix S` | 输入名称，新建并切换到 Session |
| `Prefix :`，输入 `new-session -s 名称` | 通过命令提示符新建 Session |
| `Prefix X s`，再按 `y` | 安全关闭当前 Session |
| `mux 名称` | 从 PowerShell 创建或进入指定 Session |
| `mux-ls` | 从 PowerShell 列出全部 Session |

### Window

Window 是 Session 内的完整工作区，每个 Window 可以包含多个 Pane。

| 按键 | 用途 |
|---|---|
| `Prefix c` | 在当前目录新建 Window |
| `Prefix n` / `Prefix p` | 下一个 / 上一个 Window |
| `Prefix Tab` | 返回刚才使用的 Window |
| `Prefix 0…9` | 按编号切换 Window；本配置从 `1` 开始编号 |
| `Prefix '` | 输入编号后切换 Window |
| `Prefix w` | 打开 Window 选择器 |
| `Prefix ,` | 重命名当前 Window |
| `Prefix X w`，再按 `y` | 使用统一关闭入口安全关闭当前 Window |
| `Prefix &` | 迁移期保留的旧关闭方式，按 `y` 确认 |

### Pane（分屏）

| 按键 | 用途 |
|---|---|
| `Alt+←/↓/↑/→` | **直接**移动到左 / 下 / 上 / 右 Pane，无需 Prefix |
| `Prefix v` | 左右分屏，并继承当前 Pane 的目录 |
| `Prefix b` | 上下分屏，并继承当前 Pane 的目录 |
| `Prefix \|` / `Prefix -` | 迁移期保留的旧分屏键，同样继承当前目录 |
| `Prefix %` / `Prefix "` | psmux 兼容分屏键，同样继承当前目录 |
| `Prefix h/j/k/l` | 迁移期保留的左 / 下 / 上 / 右导航 |
| `Prefix ←/↓/↑/→` | 永久保留的方向键导航后备方案 |
| `Prefix o` | 按顺序移动到下一个 Pane |
| `Prefix ;` | 返回刚才使用的 Pane |
| `Prefix q` | 显示 Pane 编号，再按编号跳转 |
| `Prefix X p`，再按 `y` | 使用统一关闭入口安全关闭当前 Pane |
| `Prefix x` | 迁移期保留的旧关闭方式，按 `y` 确认 |
| `exit` | 从当前 Shell 退出并关闭所在 Pane |
| `Prefix z` | 最大化当前 Pane / 恢复原布局 |
| `Prefix {` / `Prefix }` | 与上一个 / 下一个 Pane 交换位置 |
| `Prefix !` | 把当前 Pane 拆成独立 Window |

### 调整 Pane 与布局

| 按键 | 用途 |
|---|---|
| `Alt+Shift+←/↓/↑/→` | **直接**向对应方向调整，横向 3 格、纵向 2 格 |
| `Prefix H/J/K/L` | 迁移期保留的左 / 下 / 上 / 右调整方式 |
| `Prefix C-方向键` | 向对应方向微调 1 格 |
| `Prefix M-方向键` | 向对应方向快速调整 5 格 |
| `Prefix Space` | 循环切换预设布局 |
| `Prefix M-1` | `even-horizontal`：Pane 等宽横排 |
| `Prefix M-2` | `even-vertical`：Pane 等高竖排 |
| `Prefix M-3` | `main-horizontal`：主 Pane 在上 |
| `Prefix M-4` | `main-vertical`：主 Pane 在左 |
| `Prefix M-5` | `tiled`：平铺所有 Pane |

### 复制、选择与缓冲区

| 按键 | 用途 |
|---|---|
| `Prefix [` | 进入 vi 复制模式 |
| `Prefix PageUp` | 进入复制模式并向上翻页 |
| `PageUp` | 原样交给 Neovim、Yazi、fzf 或当前前台程序 |
| `Space` | 在复制模式中开始选择 |
| `v` | 在复制模式中切换矩形选择 |
| `y` | 复制所选内容并退出复制模式 |
| `q` / `Escape` | 退出复制模式，不复制 |
| `Prefix ]` | 粘贴最近的 psmux buffer |
| `Prefix =` | 选择一个 buffer 后粘贴 |
| `Prefix #` | 列出所有 buffer |

复制模式使用 vi 导航：`h/j/k/l` 移动，`Ctrl+U` / `Ctrl+D` 上下半页，`g` / `G`
前往开头 / 结尾。启用鼠标后，也可以滚轮回看、点击切换 Pane、拖动边界调整大小。

### psmux 控制与诊断

| 按键 | 用途 |
|---|---|
| `Prefix :` | 打开 psmux 命令提示符 |
| `Prefix ?` | 显示当前实际生效的全部键位 |
| `Prefix i` | 显示当前 Session、Window 和 Pane 信息 |
| `Prefix t` | 显示时钟 |
| `Prefix r` | 重新加载 `~/.psmux.conf` |
| `Prefix Prefix` | 向前台程序发送原始 `Ctrl+A` |

只接管 Windows Terminal 原本已占用的 `Alt+方向键` 和 `Alt+Shift+方向键`；没有占用
应用常见的 Alt 字母或 Ctrl 组合键，因此不会新增 Neovim、Amp、fzf、Yazi 或 PSReadLine
冲突。遇到文档与安装版本不一致时，以 `Prefix ?` 或 `psmux list-keys` 的输出为准。

## Neovim、Amp 与剪贴板

- `Ctrl+V` 会原样传给 Neovim，用于 Visual Block。
- Windows Terminal 粘贴改为 `Ctrl+Shift+V`，右键粘贴仍可用。
- Windows Terminal 的 Alt 方向键已释放给 psmux；外层 Terminal Pane 请使用鼠标管理。
- Amp 多行输入使用 `Ctrl+J`；psmux 不绑定它。
- 若 Windows Terminal 能发送修改后的 Enter，`Shift+Enter` 会透传给 Amp。
- `mux-dev` 在同一项目目录启动 Neovim 和 Amp，`amp.nvim` 能自动匹配 workspace。
- 鼠标可切换/缩放 pane，也会转发给 Neovim、Yazi 和 Amp；终端文本矩形选择已关闭。

## PowerShell 预测补全

psmux 默认会禁用 PSReadLine prediction。本配置显式启用 `allow-predictions on`，因此
Profile 中的 HistoryAndPlugin、CompletionPredictor 和 ListView 继续生效；同时关闭
psmux 的额外 prediction dimming，避免 TUI 重绘异常。

## 配置与诊断

```powershell
edit-psmux
mux-reload
psmux list-keys
psmux show-options -g
psmux --version
```

Tokyo Night 状态栏、Nerd Font 图标、10 万行 scrollback、vi copy mode、鼠标、1-based
window/pane、当前目录继承均已启用。顶部 pane title 有已知的光标行偏移问题，因此只保留
活动边框颜色，不显示 title 行。Windows Terminal 自身的 pane 与 psmux pane 是两层独立
布局；日常开发建议只用 psmux pane，避免嵌套布局混淆。
