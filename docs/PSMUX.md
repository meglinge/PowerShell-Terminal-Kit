# psmux：原生 Windows 终端复用器

psmux 直接使用 Windows ConPTY，不需要 WSL、Cygwin、Git Bash 或其他 Shell。所有 pane
继续运行 PowerShell 7。配置文件是 `~/.psmux.conf`，语法兼容 tmux。

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

## 键位

前缀键是 `Ctrl+A`。表格中的按键都先按前缀，再按第二个键。

| 按键 | 用途 |
|---|---|
| `Ctrl+A`，再按 `Ctrl+A` | 向程序发送原始 Ctrl+A |
| `Ctrl+A |` | 左右分割，并继承当前目录 |
| `Ctrl+A -` | 上下分割，并继承当前目录 |
| `Ctrl+A c` | 在当前目录创建 Window |
| `Ctrl+A h/j/k/l` | 移动到左/下/上/右 pane |
| `Ctrl+A H/J/K/L` | 调整 pane 大小 |
| `Ctrl+A 1…9` | 切换 Window |
| `Ctrl+A Tab` | 返回上一个 Window |
| `Ctrl+A q` | 显示 pane 编号并按编号跳转 |
| `Ctrl+A [` | 进入 vi 复制模式；`Space` 选择、`y` 复制 |
| `Ctrl+A ]` | 粘贴 psmux buffer |
| `Ctrl+A z` | 放大/恢复当前 pane |
| `Ctrl+A d` | Detach，保留 session |
| `Ctrl+A s` | Session 选择器 |
| `Ctrl+A w` | Window/Session 树 |
| `Ctrl+A r` | 重新加载 `~/.psmux.conf` |

没有设置无前缀的 Alt/Ctrl 导航，因此不会抢占 Neovim、Amp、fzf、Yazi 或 PSReadLine
按键。PowerShell 的 Ctrl+A 如需传入，请连续按两次 Ctrl+A。

## Neovim、Amp 与剪贴板

- `Ctrl+V` 会原样传给 Neovim，用于 Visual Block。
- Windows Terminal 粘贴改为 `Ctrl+Shift+V`，右键粘贴仍可用。
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
window/pane、当前目录继承均已启用。Windows Terminal 自身的 pane 与 psmux pane 是两层
独立布局；日常开发建议只用 psmux pane，避免嵌套布局混淆。
