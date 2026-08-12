# Neovim 0.12 配置

本配置要求 Neovim 0.12+，直接使用内置的实验性但已可日常使用的 `vim.pack`。不安装
lazy.nvim，也不引入完整 Neovim 发行版。插件锁定在 `nvim-pack-lock.json`；首次运行
`nvim` 时并行下载，后续启动直接复用。

## 插件清单

| 插件 | 用途 |
|---|---|
| `nvim-mini/mini.nvim` | 文件选择、文件管理器、图标、状态栏、自动括号、环绕编辑、按键提示 |
| `nvim-treesitter/nvim-treesitter` | 现代语法树高亮；使用适配 0.12 的 `main` API |
| `neovim/nvim-lspconfig` | PowerShell、Lua、Markdown 和可选语言的 LSP 配置 |
| `mason.nvim` | 下载和管理语言服务器 |
| `mason-lspconfig.nvim` | Mason 与 Neovim 原生 LSP 的映射 |
| `mason-tool-installer.nvim` | 延迟异步安装 Stylua、Ruff 和可选 Prettier |
| `conform.nvim` | 保存时格式化，并在工具缺失时回退到 LSP |
| `gitsigns.nvim` | Git 修改标记、预览、暂存和回滚 hunk |
| `tokyonight.nvim` | 与 Windows Terminal 一致的 Tokyo Night Moon 配色 |

没有安装 `nvim-cmp`、Telescope、Neo-tree、WhichKey、Lualine 或额外图标插件：Neovim
0.12 原生补全与 `mini.nvim` 已覆盖这些职责。

## 首次启动

```powershell
nvim
```

Mason 默认安装 PowerShell、Lua 和 Markdown 语言服务器。如果系统已存在 Node.js、Go
或 Rust，还会分别启用 JSON/Python/TypeScript、gopls、rust-analyzer。

Treesitter 新版在 Windows 安装额外 parser 时要求 `tree-sitter-cli >= 0.26.1` 和 C
编译器。安装器提供 CLI；检测到 LLVM/Clang、GCC 或 MSVC 后可在 Neovim 中执行：

```vim
:TSInstall powershell lua vim vimdoc query json markdown markdown_inline python javascript typescript tsx go gomod gosum gowork rust
```

插件更新使用：

```vim
:packupdate
```

审阅变更后 `:write` 接受、`:quit` 放弃；Treesitter 更新后再执行 `:TSUpdate`，然后
`:restart`。健康检查：`:checkhealth vim.pack`、`:checkhealth mason`、
`:checkhealth vim.lsp`、`:checkhealth nvim-treesitter`、`:ConformInfo`。

## 常用快捷键

`<leader>` 是空格。

| 快捷键 | 用途 |
|---|---|
| `Space f f` | 查找文件 |
| `Space f g` | 全文实时搜索（有 ripgrep 时最快） |
| `Space f b` | 切换 Buffer |
| `Space f h` | 搜索帮助 |
| `Space e` | 打开 MiniFiles 文件管理器 |
| `Space c f` | 格式化当前文件或选区 |
| `Space c d` | 显示当前行诊断 |
| `[d` / `]d` | 上一个/下一个诊断 |
| `[c` / `]c` | 上一个/下一个 Git hunk |
| `Space h p/s/r` | 预览/暂存/还原 Git hunk |
| `Space g g` | 在分屏终端打开 LazyGit |
| `gd` / `grr` / `gra` / `grn` | 定义/引用/代码操作/重命名（Neovim 原生 LSP） |
| `K` | 悬浮文档 |
| `Ctrl+Space` | 手动触发原生 LSP 补全 |
| `Ctrl+h/j/k/l` | 在窗口间移动 |

## 外部工具

- 必需：Git、Neovim 0.12+。
- 推荐：ripgrep、fd、LazyGit、Maple Mono NF CN；终端套件会安装。
- Treesitter 新 parser：tree-sitter CLI 与 C 编译器。
- TypeScript/JSON/Pyright：Node.js；Go：Go 工具链；Rust：Rustup。
- 格式器可通过 `:Mason` 或系统包管理器安装，例如 Stylua、Ruff、Prettier。
