local map = vim.keymap.set

map('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Clear search highlight' })
map('n', '<leader>w', '<cmd>write<CR>', { desc = 'Write file' })
map('n', '<leader>q', '<cmd>quit<CR>', { desc = 'Quit window' })

map('n', '<C-h>', '<C-w><C-h>', { desc = 'Focus left window' })
map('n', '<C-j>', '<C-w><C-j>', { desc = 'Focus lower window' })
map('n', '<C-k>', '<C-w><C-k>', { desc = 'Focus upper window' })
map('n', '<C-l>', '<C-w><C-l>', { desc = 'Focus right window' })

map('n', '<leader>ff', function() MiniPick.builtin.files() end, { desc = 'Find files' })
map('n', '<leader>fg', function() MiniPick.builtin.grep_live() end, { desc = 'Live grep' })
map('n', '<leader>fb', function() MiniPick.builtin.buffers() end, { desc = 'Buffers' })
map('n', '<leader>fh', function() MiniPick.builtin.help() end, { desc = 'Help tags' })
map('n', '<leader>e', function()
  local path = vim.api.nvim_buf_get_name(0)
  MiniFiles.open(path ~= '' and path or vim.uv.cwd(), false)
end, { desc = 'File explorer' })

map({ 'n', 'x' }, '<leader>cf', function()
  require('conform').format({ async = true, lsp_format = 'fallback' })
end, { desc = 'Format' })

map('n', '<leader>gg', function()
  vim.cmd('botright split | terminal lazygit')
  vim.cmd.startinsert()
end, { desc = 'LazyGit' })

map('n', '[d', function() vim.diagnostic.jump({ count = -1, float = true }) end,
  { desc = 'Previous diagnostic' })
map('n', ']d', function() vim.diagnostic.jump({ count = 1, float = true }) end,
  { desc = 'Next diagnostic' })
map('n', '<leader>cd', vim.diagnostic.open_float, { desc = 'Line diagnostics' })
