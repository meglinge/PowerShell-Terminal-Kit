if vim.fn.has('nvim-0.12') ~= 1 then
  error('PowerShell Terminal Kit requires Neovim 0.12 or newer')
end

vim.loader.enable()
vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'

require('config.options')
require('config.plugins')
require('config.keymaps')
require('config.autocmds')
