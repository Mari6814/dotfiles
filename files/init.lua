-- Vim settings
vim.g.mapleader = " "
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.wildmenu = true
vim.opt.wildmode = {'longest', 'list', 'full'}
vim.opt.wildignore = {'*~', '*.pyc', '**/node_modules/**', '**/.git/**', '.DS_Store'}
vim.opt.matchpairs:append({'<:>'})
vim.opt.foldmethod = 'indent'
vim.opt.list = true
vim.opt.listchars = {tab = '▸ ', trail = '·', extends = '❯', precedes = '❮', nbsp = '␣'}

-- Map moving windows in normal mode
vim.keymap.set('n', '<C-h>', '<C-w>h', {})
vim.keymap.set('n', '<C-j>', '<C-w>j', {})
vim.keymap.set('n', '<C-k>', '<C-w>k', {})
vim.keymap.set('n', '<C-l>', '<C-w>l', {})

-- Close & save shortcuts
vim.keymap.set('n', '<leader>q', ':q<CR>', {})
vim.keymap.set('n', '<leader>Q', ':qa<CR>', {})
vim.keymap.set('n', '<leader>x', ':x<CR>', {})
vim.keymap.set('n', '<leader>X', ':xa<CR>', {})

-- Navigate buffers
vim.keymap.set('n', '<leader>b', ':ls<CR>:b ', {})
vim.keymap.set('n', ']b', ':bnext<CR>', {})
vim.keymap.set('n', '[b', ':bprevious<CR>', {})

-- Tab shortcuts
vim.keymap.set('n', '<leader>t', ':tabnew %<CR>', {})
vim.keymap.set('n', ']t', ':tabnext<CR>', {})
vim.keymap.set('n', '[t', ':tabprevious<CR>', {})

-- Navigate the quickfix list
vim.keymap.set('n', '<leader>c', ':copen<CR>', {})
vim.keymap.set('n', ']c', ':cnext<CR>', {})
vim.keymap.set('n', '[c', ':cprevious<CR>', {})

-- Find beginning of word
vim.keymap.set('n', 'gw', '/\\<', {})
vim.keymap.set('n', 'gW', ':vim /\\</ **<left><left><left><left>', {})

-- Replace word under cursor
vim.keymap.set('n', '<leader>rw', ':%s/<C-r><C-w>//g<Left><Left>', {})
vim.keymap.set('v', '<leader>rw', 'y:%s/<C-r>"//g<Left><Left>', {})

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    { 'nvim-telescope/telescope.nvim', tag = '0.1.1', dependencies = { 'nvim-lua/plenary.nvim' } },
    { 'github/copilot.vim', lazy = false },
    { 'neovim/nvim-lspconfig', lazy = false},
    { 'tpope/vim-fugitive', lazy = false},
})

local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})
