local gh = function(repo)
  return 'https://github.com/' .. repo
end

vim.pack.add({
  { src = gh('nvim-mini/mini.nvim'), version = 'stable' },
  { src = gh('folke/tokyonight.nvim') },
  { src = gh('nvim-treesitter/nvim-treesitter'), version = 'main' },
  { src = gh('neovim/nvim-lspconfig') },
  { src = gh('mason-org/mason.nvim'), version = vim.version.range('^2') },
  { src = gh('mason-org/mason-lspconfig.nvim'), version = vim.version.range('^2') },
  { src = gh('WhoIsSethDaniel/mason-tool-installer.nvim') },
  { src = gh('stevearc/conform.nvim') },
  { src = gh('lewis6991/gitsigns.nvim') },
}, { confirm = false, load = true })

require('tokyonight').setup({
  style = 'moon',
  styles = { comments = { italic = true }, keywords = { italic = true } },
})
vim.cmd.colorscheme('tokyonight')

require('mini.icons').setup({ style = 'glyph' })
require('mini.pick').setup()
require('mini.files').setup({ windows = { preview = true, width_preview = 50 } })
require('mini.statusline').setup({ use_icons = true })
require('mini.pairs').setup()
require('mini.surround').setup()

local clue = require('mini.clue')
clue.setup({
  window = { config = { border = 'rounded' } },
  triggers = {
    { mode = { 'n', 'x' }, keys = '<Leader>' },
    { mode = 'n', keys = '[' },
    { mode = 'n', keys = ']' },
    { mode = 'i', keys = '<C-x>' },
    { mode = { 'n', 'x' }, keys = 'g' },
    { mode = { 'n', 'x' }, keys = 'z' },
    { mode = 'n', keys = '<C-w>' },
    { mode = { 'n', 'x' }, keys = "'" },
    { mode = { 'n', 'x' }, keys = '`' },
    { mode = { 'n', 'x' }, keys = '"' },
    { mode = { 'i', 'c' }, keys = '<C-r>' },
  },
  clues = {
    clue.gen_clues.square_brackets(),
    clue.gen_clues.builtin_completion(),
    clue.gen_clues.g(),
    clue.gen_clues.z(),
    clue.gen_clues.windows(),
    clue.gen_clues.marks(),
    clue.gen_clues.registers(),
  },
})

require('nvim-treesitter').setup({
  install_dir = vim.fn.stdpath('data') .. '/site',
})

local treesitter_filetypes = {
  'powershell', 'lua', 'vim', 'vimdoc', 'query', 'json', 'jsonc', 'markdown',
  'python', 'javascript', 'javascriptreact', 'typescript', 'typescriptreact',
  'go', 'gomod', 'gowork', 'rust',
}
vim.api.nvim_create_autocmd('FileType', {
  pattern = treesitter_filetypes,
  callback = function(event)
    pcall(vim.treesitter.start, event.buf)
  end,
})

require('mason').setup({ PATH = 'prepend', ui = { border = 'rounded' } })

local servers = { 'powershell_es', 'lua_ls', 'marksman' }
if vim.fn.executable('node') == 1 then
  vim.list_extend(servers, { 'jsonls', 'pyright', 'ts_ls' })
end
if vim.fn.executable('go') == 1 then
  table.insert(servers, 'gopls')
end
if vim.fn.executable('rustc') == 1 then
  table.insert(servers, 'rust_analyzer')
end

vim.lsp.config('lua_ls', {
  settings = {
    Lua = {
      runtime = { version = 'LuaJIT' },
      workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
    },
  },
})
vim.lsp.config('rust_analyzer', {
  settings = { ['rust-analyzer'] = { check = { command = 'clippy' } } },
})

require('mason-lspconfig').setup({
  ensure_installed = servers,
  automatic_enable = false,
})
vim.lsp.enable(servers)

local tools = { 'stylua', 'ruff' }
if vim.fn.executable('node') == 1 then
  table.insert(tools, 'prettier')
end
require('mason-tool-installer').setup({
  ensure_installed = tools,
  run_on_start = true,
  start_delay = 3000,
  debounce_hours = 24,
})

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client:supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, client.id, event.buf, { autotrigger = true })
    end
    vim.keymap.set('i', '<C-Space>', vim.lsp.completion.get,
      { buffer = event.buf, desc = 'Completion' })
  end,
})

require('conform').setup({
  default_format_opts = { lsp_format = 'fallback', timeout_ms = 2500 },
  formatters_by_ft = {
    lua = { 'stylua' },
    python = { 'ruff_format' },
    javascript = { 'prettier', stop_after_first = true },
    javascriptreact = { 'prettier', stop_after_first = true },
    typescript = { 'prettier', stop_after_first = true },
    typescriptreact = { 'prettier', stop_after_first = true },
    json = { 'prettier', stop_after_first = true },
    jsonc = { 'prettier', stop_after_first = true },
    markdown = { 'prettier', stop_after_first = true },
    go = { 'gofmt' },
    rust = { 'rustfmt' },
  },
  format_on_save = { lsp_format = 'fallback', timeout_ms = 2500 },
})

require('gitsigns').setup({
  on_attach = function(buffer)
    local gs = require('gitsigns')
    vim.keymap.set('n', ']c', function()
      if vim.wo.diff then return ']c' end
      vim.schedule(function() gs.nav_hunk('next') end)
      return '<Ignore>'
    end, { expr = true, buffer = buffer, desc = 'Next Git hunk' })
    vim.keymap.set('n', '[c', function()
      if vim.wo.diff then return '[c' end
      vim.schedule(function() gs.nav_hunk('prev') end)
      return '<Ignore>'
    end, { expr = true, buffer = buffer, desc = 'Previous Git hunk' })
    vim.keymap.set('n', '<leader>hp', gs.preview_hunk,
      { buffer = buffer, desc = 'Preview hunk' })
    vim.keymap.set('n', '<leader>hs', gs.stage_hunk,
      { buffer = buffer, desc = 'Stage hunk' })
    vim.keymap.set('n', '<leader>hr', gs.reset_hunk,
      { buffer = buffer, desc = 'Reset hunk' })
  end,
})
