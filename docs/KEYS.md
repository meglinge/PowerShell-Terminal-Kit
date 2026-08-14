# 快捷键与命令

## PowerShell / PSReadLine

| 按键 | 功能 |
|---|---|
| `↑` / `↓` | 按当前前缀搜索历史 |
| `Ctrl+Space` | 补全菜单 |
| `Ctrl+→` | 向前移动/接受一个单词 |
| `Ctrl+Backspace` | 删除前一个单词 |
| `Tab` | 首次加载 Carapace，随后菜单补全 |
| `Ctrl+T` | fzf-icons 内置 walker 文件选择 |
| `Ctrl+R` | fzf 历史搜索 |

## Windows Terminal

| 按键 | 功能 |
|---|---|
| `Ctrl+C` / `Ctrl+Shift+V` | 复制 / 粘贴；保留 Ctrl+V 给 Neovim Visual Block |
| `Ctrl+Shift+F` | 搜索终端内容 |
| `Ctrl+Shift+P` | 命令面板 |
| `F11` | 专注模式 |
| `Alt+Shift+D` | 自动拆分窗格 |
| `Alt+Shift++` | 向右拆分 |
| `Alt+Shift+-` | 向下拆分 |

## psmux

前缀为 `Ctrl+A`：`|` / `-` 左右/上下分割，`h/j/k/l` 移动 pane，
`H/J/K/L` 调整大小，`c` 新建 Window，`d` detach，`[` 进入 vi copy mode。
完整表格见 [PSMUX.md](PSMUX.md)。

## Yazi（Ranger 风格）

用 `ya` 启动，才能在退出后改变父 PowerShell 的目录。

| 按键 | 功能 |
|---|---|
| `h` / `l` | 父目录 / 进入目录或打开文件 |
| `j` / `k` | 下 / 上 |
| `gg` / `G` | 顶部 / 底部 |
| `H` / `L` | 历史后退 / 前进 |
| `zh` | 隐藏文件开关 |
| `Space` | 选择并下移 |
| `v` | 可视选择 |
| `yy` / `dd` / `pp` | 复制 / 剪切 / 粘贴 |
| `cw` | 重命名 |
| `a` | 创建文件或目录 |
| `dD` | 移至回收站 |
| `/` | 当前目录查找 |
| `n` / `N` | 下一个 / 上一个匹配 |
| `r` | 选择打开方式 |
| `q` | 退出，PowerShell 进入 Yazi 当前目录 |
| `Shift+S` | 不用预先进入：进入光标目录，退出并切换 PowerShell |

`Shift+S` 光标若停在普通文件上，`enter` 可能打开文件而不是退出；该快捷键用于目录。

## 辅助命令

| 命令 | 功能 |
|---|---|
| `j foo` / `ji` | zoxide 直接 / 交互跳转 |
| `ls` / `ll` / `la` | Nushell 风格圆角列表 |
| `lso` | 原始 PowerShell 文件对象 |
| `which name` | 查看命令来源 |
| `touch file` | 创建文件或更新时间 |
| `mkcd dir` | 创建并进入目录 |
| `up 2` | 返回两级 |
| `ports` | 查看监听端口 |
| `path` | 逐行显示 PATH |
