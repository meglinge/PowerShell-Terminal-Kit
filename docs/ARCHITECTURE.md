# Architecture

## 边界

本套件只把 PowerShell 7 作为交互 Shell。Windows Terminal 是宿主，Yazi、fzf、
zoxide 等是原生子进程；没有 shell 语义翻译层。

## 启动路径

1. Windows Terminal 以 `pwsh.exe -NoLogo` 启动。
2. Profile 只同步初始化 UTF-8、PSReadLine、prompt 和 zoxide。
3. `PowerShell.OnIdle` 在首个提示符之后导入 Fast-TerminalIcons、PSFzf 和
   CompletionPredictor。
4. Carapace 只在首次 Tab 时生成/读取缓存，并把大量 completer 注册合并为一次。

## 文件图标

### fzf

仓库内 `fzf.exe` 是 fzf fork 的 Windows 构建。`--walker-icons` 仅在内置 fastwalk
产生候选时添加 display icon；匹配、Enter、多选、placeholder、shell 输出与
`--print0` 始终使用 raw path。stdin 和自定义 command 不做隐式装饰。

### ls

Fast-TerminalIcons 是 netstandard2.0 C# binary module。名称、扩展名、图标和颜色映射
在编译时生成，不在导入时读取主题文件。圆角表格由一个 compiled cmdlet 使用
StringBuilder 构建，ANSI 不计入列宽，并处理 CJK 双宽字符与 supplementary glyph。

完整边框需要知道第一行和最后一行，因此 `ls` 返回 rendered string。`lso` 是明确的
对象通道，不经过格式化器。

## 安装事务

安装器先记录每个目标是否存在并复制备份，再写入配置。manifest 保存目标与备份映射。
Windows Terminal 设置按属性合并：

- 保留未知的顶层设置。
- 保留所有现有 Profile。
- 保留除同名 Tokyo Night 以外的 scheme。
- 只更新全局视觉 defaults、PowerShell 7 Profile、快捷键和 Tokyo Night。

卸载器按 manifest 恢复；在恢复前再保存一次当前状态，因此回滚也不会无备份地覆盖。

## 供应链

- WinGet：应用和原生 CLI。
- PSGallery：PowerShell 模块。
- GitHub Releases API：Maple Mono 官方 stable NF-CN asset。
- 仓库 assets：特定版本的自研 fzf 和 Fast-TerminalIcons，使用固定 SHA-256 验证。
