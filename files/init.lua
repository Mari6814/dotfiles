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
    { 'tpope/vim-fugitive' },
    { 'vimwiki/vimwiki' },
})

local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})

-- Create inser mode abbrevs for vimwiki: [] to create todo, # to create headings, etc.
vim.api.nvim_create_autocmd('FileType', {
    desc='vimwiki',
    pattern='vimwiki',
    callback=function(opts)
        -- Headings
        vim.api.nvim_command('iabbrev <buffer> # = =<left><left>')
        -- Todo
        vim.api.nvim_command('iabbrev <buffer> [] - [ ]')
        vim.api.nvim_command('iabbrev <buffer> [x] - [x]')
        vim.api.nvim_command('iabbrev <buffer> [X] - [X]')
    end,
})

local lspconfig = require('lspconfig')
-- npm i -g bash-language-server
lspconfig.bashls.setup{}
-- pip install pyright
lspconfig.pyright.setup {}
-- npm install -g typescript typescript-language-server
lspconfig.tsserver.setup {}
-- installed with rust
lspconfig.rust_analyzer.setup{}


-- Global mappings.
-- See `:help vim.diagnostic.*` for documentation on any of the below functions
vim.keymap.set('n', '<space>e', vim.diagnostic.open_float)
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist)

-- Use LspAttach autocommand to only map the following keys
-- after the language server attaches to the current buffer
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    -- Enable completion triggered by <c-x><c-o>
    vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

    -- Buffer local mappings.
    -- See `:help vim.lsp.*` for documentation on any of the below functions
    local opts = { buffer = ev.buf }
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
    vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
    vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
    vim.keymap.set('n', '<space>wl', function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, opts)
    vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, opts)
    vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set({ 'n', 'v' }, '<space>ca', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
    vim.keymap.set('n', '<space>f', function()
      vim.lsp.buf.format { async = true }
    end, opts)
  end,
})
