-- Vim settings
vim.g.mapleader = ","
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
vim.opt.list = true
vim.opt.listchars = {tab = '▸ ', trail = '·', extends = '❯', precedes = '❮', nbsp = '␣'}
vim.opt.fillchars = { fold = " " }
vim.opt.foldmethod = "indent"
vim.opt.foldenable = false
vim.opt.foldlevel = 99

-- Misc
vim.keymap.set('n', '<esc>', ':noh<CR>') -- Clear search highlights on escape
vim.keymap.set('n', 'g*', '*``zzcgn') -- Shortcut for the *cgn pattern: 
vim.keymap.set('n', 'Y', 'y$') -- Yank to end of line
vim.keymap.set('n', '<F5>', ':wa<CR>:make<CR>') -- Run make on F5
vim.keymap.set('n', 'ge', '"eyi`:term<CR>"epA') -- Run the current/next code block in a terminal
vim.keymap.set('n', 'gE', '"eyi`:!<C-r>e') -- Run the current/next code block inline in the current window
vim.keymap.set('i', '<F5>', '<C-o>:wa<CR>:make<CR>') -- Run make on F5 in insert mode
vim.keymap.set('t', '<esc>', '<C-\\><C-n>') -- Simplify terminal mode exit shortcut
vim.keymap.set('n', '<C-x>', ':x<CR>') -- Close window with saving
vim.keymap.set('n', '<C-w>w', ':bd<CR>') -- Extend <c-w> by a shortcut to close the current buffer
vim.keymap.set('i', '<C-s>', '<C-o>:w<CR>') -- in insert mode, only save current buffer

-- Window navigation shortcuts in normal, insert & terminal modes
vim.keymap.set('n', '<C-h>', '<C-w>h')
vim.keymap.set('n', '<C-j>', '<C-w>j')
vim.keymap.set('n', '<C-k>', '<C-w>k')
vim.keymap.set('n', '<C-l>', '<C-w>l')
vim.keymap.set('i', '<C-h>', '<C-o><C-w>h')
vim.keymap.set('i', '<C-j>', '<C-o><C-w>j')
vim.keymap.set('i', '<C-k>', '<C-o><C-w>k')
vim.keymap.set('i', '<C-l>', '<C-o><C-w>l')
vim.keymap.set('t', '<C-h>', '<C-\\><C-n><C-w>h')
vim.keymap.set('t', '<C-j>', '<C-\\><C-n><C-w>j')
vim.keymap.set('t', '<C-k>', '<C-\\><C-n><C-w>k')
vim.keymap.set('t', '<C-l>', '<C-\\><C-n><C-w>l')

-- Navigate quickfix list, location list, buffer list, tab list, window list
vim.keymap.set('n', '[g', vim.diagnostic.goto_next)
vim.keymap.set('n', ']g', vim.diagnostic.goto_prev)
vim.keymap.set('n', '[q', ':cprev<CR>')
vim.keymap.set('n', ']q', ':cnext<CR>')
vim.keymap.set('n', '[l', ':lprev<CR>')
vim.keymap.set('n', ']l', ':lnext<CR>')
vim.keymap.set('n', '[b', ':bprev<CR>')
vim.keymap.set('n', ']b', ':bnext<CR>')
vim.keymap.set('n', '[t', ':tabprev<CR>')
vim.keymap.set('n', ']t', ':tabnext<CR>')
vim.keymap.set('n', '[w', ':wincmd w<CR>')
vim.keymap.set('n', ']w', ':wincmd W<CR>')

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
    -- $ sudo apt install ripgrep fd-find
    -- $ git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install
    { 'nvim-telescope/telescope.nvim',
        dependencies = { 'nvim-lua/plenary.nvim' },
        build="git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install",
        init = function ()
            local builtin = require('telescope.builtin')
            vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
            vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
            vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
            vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})
        end
    },
    { 'github/copilot.vim' },
    { 'neovim/nvim-lspconfig' },
    { 'tpope/vim-fugitive' },
    { 'vimwiki/vimwiki', init = function (plug)
        -- Create inser mode abbrevs for vimwiki: [] to create todo, # to create headings, etc.
        vim.g.vimwiki_global_ext = 0;
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
        end,
    },
    { 'tpope/vim-dadbod', },
    { 'stevearc/oil.nvim',
        lazy = false, -- required to be able to do `$ nvim .`
        opts = { default_file_explorer = true },
        keys = {
            { "-", "<CMD>Oil<CR>", { desc = "Open parent directory" } },
        },
        dependencies={
            'nvim-tree/nvim-web-devicons'
        },
    },
})

-- $ pip install nginx-language-server
require'lspconfig'.nginx_language_server.setup{}
-- $ npm i -g bash-language-server
require'lspconfig'.bashls.setup{} 
-- $ npm i -g pyright
require'lspconfig'.pyright.setup{}
-- $ npm i -g typescript typescript-language-server
require'lspconfig'.tsserver.setup{}
-- $ npm i -g @ansible/ansible-language-server
require'lspconfig'.ansiblels.setup{}
-- $ npm i -g dockerfile-language-server-nodejs
require'lspconfig'.dockerls.setup{}
-- $ npm i -g vim-language-server
require'lspconfig'.vimls.setup{}
-- $ npm i -g vscode-langservers-extracted
require'lspconfig'.html.setup{}
-- $ npm i -g @tailwindcss/language-server
require'lspconfig'.tailwindcss.setup{}
-- $ go install golang.org/x/tools/gopls@latest
require'lspconfig'.gopls.setup{}
-- $ cargo install htmx-lsp
require'lspconfig'.htmx.setup{}
require'lspconfig'.templ.setup{}
require'lspconfig'.rust_analyzer.setup{}

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
    vim.keymap.set('n', 'gk', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', 'gK', vim.lsp.buf.signature_help, opts)
    vim.keymap.set('n', '<leader>wa', vim.lsp.buf.add_workspace_folder, opts)
    vim.keymap.set('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder, opts)
    vim.keymap.set('n', '<leader>wl', function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, opts)
    vim.keymap.set('n', '<leader>D', vim.lsp.buf.type_definition, opts)
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
    vim.keymap.set('n', '<leader>F', function()
      vim.lsp.buf.format { async = true }
    end, opts)
  end,
})

-- augroup for saving python, then running 'black' formatter if it is installed
vim.api.nvim_create_autocmd('BufWritePost', {
  group = vim.api.nvim_create_augroup('UserPythonBlack', {}),
  pattern = '*.py',
  callback = function()
    vim.cmd('silent! !black %')
  end,
})
