# PowerShell Terminal Kit

一套以 **PowerShell 7 为唯一 Shell 基底**的 Windows Terminal 环境。它提供接近
Zsh/Nushell 的视觉与交互，但不引入 Zsh、Nushell、WSL 或 Git Bash 的兼容性层。

## 效果与特性

- Tokyo Night、Maple Mono NF CN、亚克力背景和紧凑 Windows Terminal 布局。
- 原生 PowerShell `robbyrussell` 风格提示符，显示当前目录、Git 分支和 dirty 状态。
- PSReadLine 彩色语法、历史与插件预测、Carapace 原生 CLI 补全。
- `Ctrl+T` 使用自研 `fzf-icons` 的**内置 fastwalk**：原生扫描速度与完整文件图标兼得。
- `Ctrl+R` 使用 fzf 搜索 PowerShell 历史。
- `ls` / `ll` / `la` 使用 C# 二进制渲染 Nushell 风格圆角表格。
- `lso` 保留原始 `FileInfo` / `DirectoryInfo` 对象管道。
- zoxide 提供 `j` / `ji` 智能目录跳转。
- Yazi 使用 Ranger 键位；`ya` 启动，光标停在目录上按 `Shift+S` 即退出并进入该目录。
- btop、lazygit、dust、jq、just、ripgrep、fd 等现代原生命令行工具。
- 慢模块在首次提示符后预热，Carapace 在首次 Tab 时加载。

```text
╭──────┬───────────┬──────────────────┬───────────────────────────╮
│ type │      size │ modified         │ name                      │
├──────┼───────────┼──────────────────┼───────────────────────────┤
│ dir  │         — │ 2026-08-12 08:27 │   artifacts              │
│ file │   1.5 KiB │ 2026-08-12 14:26 │ 󰞷  Build.ps1              │
╰──────┴───────────┴──────────────────┴───────────────────────────╯
```

## 一键安装

要求：Windows 10/11、WinGet，以及能够联网访问 WinGet、PSGallery 和 GitHub。
不需要管理员 PowerShell；字体按当前用户安装。

下载或克隆本仓库，在仓库根目录执行：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

安装器会：

1. 自动备份已有 PowerShell Profile、Yazi 键位和 Windows Terminal 设置。
2. 通过 WinGet 安装 PowerShell、Windows Terminal 和全部原生工具。
3. 从 PSGallery 安装 PSReadLine、PSFzf 和 CompletionPredictor。
4. 从 Maple Mono 官方稳定 Release 安装 Maple Mono NF CN。
5. 安装仓库内经过校验的 `fzf-icons` 与 `Fast-TerminalIcons`。
6. 结构化合并 Windows Terminal 设置，保留用户已有的其他 Profile 和配色。

安装完成后关闭**所有** Windows Terminal 窗口，重新打开，再验证：

```powershell
pwsh -NoProfile -File .\verify.ps1
```

### 安装选项

```powershell
# 只预览，不修改任何内容
.\install.ps1 -DryRun

# 已有所有工具，只部署配置和自研组件
.\install.ps1 -SkipPackages

# 不下载字体
.\install.ps1 -SkipFont

# 不修改 Windows Terminal 设置
.\install.ps1 -SkipTerminalSettings
```

脚本可重复执行；每次执行都会创建新的时间戳备份。

## 回滚与卸载

恢复最近一次安装前的配置：

```powershell
pwsh -NoProfile -File .\uninstall.ps1
```

指定某次备份：

```powershell
.\uninstall.ps1 -Backup "$env:LOCALAPPDATA\PowerShellTerminalKit\backups\20260812-120000"
```

卸载器会恢复配置并移除本套件的 fzf 和 Fast-TerminalIcons 运行时。WinGet 应用、
PSGallery 模块与字体可能被其他配置共享，因此有意保留，不做破坏性删除。卸载前的
当前配置也会再次保存到 `uninstall-backups`。

## 主要命令

| 命令/按键 | 用途 |
|---|---|
| `ls` | 圆角表格，普通文件 |
| `ll` / `la` | 圆角表格，包含隐藏文件 |
| `lso` | 原始对象列表，可接 `Where-Object` / `Remove-Item` |
| `Ctrl+T` | 带图标的内置 walker 文件选择 |
| `Ctrl+R` | 模糊搜索历史命令 |
| `j keyword` | zoxide 直接跳转 |
| `ji` | zoxide + fzf 交互跳转 |
| `ya` | 启动 Yazi 并支持退出后切换目录 |
| `Shift+S`（Yazi） | 进入光标所指目录、退出 Yazi、切换 PowerShell 目录 |
| `reload-profile` | 重载 PowerShell Profile |
| `edit-profile` | 用 VS Code 编辑 Profile |

完整键位见 [docs/KEYS.md](docs/KEYS.md)。

## 设计与性能

```text
Windows Terminal (Tokyo Night + Maple Mono NF CN)
└─ PowerShell 7 -NoLogo
   ├─ 同步：UTF-8、PSReadLine、原生 prompt、zoxide
   ├─ OnIdle：Fast-TerminalIcons、PSFzf、CompletionPredictor
   ├─ 首次 Tab：Carapace
   ├─ Ctrl+T：fzf-icons 内置 fastwalk
   └─ ls：Fast-TerminalIcons C# 边框渲染器
```

- 不使用 PowerShell 循环扫描文件来生成 fzf 图标。
- 普通 `Get-ChildItem` 不额外 stat；目录大小显示 `—`，不会递归扫描。
- `Fast-TerminalIcons` direct DLL 冷导入约 10ms；10,000 项边框构建约 22ms
  （参考开发机数据，不作为所有硬件的性能保证）。
- 完整边框必须缓存列表并输出一个字符串；对象管道请使用 `lso`。
- Windows Terminal 采用合并而非覆盖，避免删除 WSL、VS、SSH 等已有 Profile。

更多实现边界见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

## 仓库布局

```text
assets/                    已校验的原生运行时与许可证
config/powershell/         可移植 PowerShell Profile
config/yazi/               Ranger 风格键位
config/windows-terminal…   可合并的 Terminal 设计片段
docs/                      架构和快捷键文档
install.ps1                幂等安装、备份和结构化合并
uninstall.ps1              从 manifest 回滚
verify.ps1                 语法、密钥、哈希、部署和回滚测试
```

## 安全与来源

- 仓库不包含用户名、个人绝对路径、GitHub Token 或其他凭据。
- 两个 bundled binary 的 SHA-256 位于 `assets/checksums.sha256`。
- fzf fork 的提交与设计来源位于 `assets/fzf-icons/PROVENANCE.md`。
- 第三方许可见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。
- 安装脚本只从 WinGet、PSGallery 与 Maple Mono 官方 GitHub Release 获取依赖。

## 开发验证

```powershell
pwsh -NoProfile -File .\verify.ps1 -RepositoryOnly
```

该命令会在临时目录执行完整部署与卸载回滚，验证 Windows Terminal 合并不会删除
已有 Profile/配色，并验证二进制哈希、fzf walker icons 与 C# 边框渲染。

## License

仓库自有脚本和配置使用 MIT License。第三方组件维持各自许可证。
