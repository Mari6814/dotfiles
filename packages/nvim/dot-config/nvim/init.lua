-- Vim settings
vim.keymap.set('n', '<space>', '<nop>', {silent=true, remap=false}) -- Unmap space
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

-- save and quite
vim.keymap.set('n', '<c-w>x', ':x<CR>')
vim.keymap.set('n', '<c-w>X', ':xa<CR>')

-- Misc
vim.keymap.set('n', '<esc>', ':noh<CR>') -- Clear search highlights on escape
vim.keymap.set('n', 'g*', '*``zzcgn') -- Shortcut for the *cgn pattern: 
vim.keymap.set('t', '<esc>', '<C-\\><C-n>') -- Simplify terminal mode exit shortcut
-- Open terminal, move to bottom, set height to 10, and set the title
vim.keymap.set('n', '<leader><leader>', ':split<CR><C-w>r:term<CR>10<C-W>_<CR>:set titlestring=Terminal<CR>A')
-- Closes the terminal window
vim.keymap.set('t', '<leader><leader>', '<C-\\><C-n>:q<CR>')
-- When on top of a line like "// :set makeprg=php", copy the ":set makeprg=php" part and enter it into the command line so that I can press Enter to execute it
vim.keymap.set('n', '<leader>n', '0f:<right>vg_y:<C-r>"<CR>')

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
    { 'nvim-treesitter/nvim-treesitter' },
    -- $ sudo apt install ripgrep fd-find
    -- $ git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install
    { 'nvim-telescope/telescope.nvim',
        dependencies = {
            'nvim-lua/plenary.nvim',
            {
                'nvim-telescope/telescope-fzf-native.nvim',
                build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release'
            }
        },
        init = function ()
            local builtin = require('telescope.builtin')
            vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
            vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
            vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
            vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})
            vim.keymap.set('n', '<leader>gb', builtin.git_branches, {})
            vim.keymap.set('n', '<leader>gs', builtin.git_status, {})
            vim.keymap.set('n', '<leader>gh', builtin.git_bcommits, {})
            vim.keymap.set('n', '<leader>gf', builtin.git_files, {})
        end
    },
    { 'github/copilot.vim' },
    { 'neovim/nvim-lspconfig' },
    { 'tpope/vim-fugitive' },
    {
      "vimwiki/vimwiki",
      cmd = { "VimwikiIndex" },
      event = "BufEnter *.md",
      keys = { "<leader>ww", "<leader>wt" },
      init = function()
        vim.g.vimwiki_list = {
          {
            path = "~/wiki/",
            syntax = "markdown",
            ext = "md",
          },
        }
        vim.g.vimwiki_ext2syntax = {
          [".md"] = "markdown",
          [".markdown"] = "markdown",
          [".mdown"] = "markdown",
        }
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

-- $ npm i -g pyright typescript typescript-language-server vim-language-server vscode-langservers-extracted @tailwindcss/language-server
require'lspconfig'.pyright.setup{}
require'lspconfig'.ts_ls.setup{}
require'lspconfig'.html.setup{}
require'lspconfig'.tailwindcss.setup{}
require'lspconfig'.gopls.setup{}
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

require'nvim-treesitter.configs'.setup{
  ensure_installed = {
    'bash',
    'css',
    'go',
    'gomod',
    'html',
    'javascript',
    'json',
    'lua',
    'markdown',
    'markdown_inline',
    'python',
    'query',
    'rust',
    'tmux',
    'toml',
    'tsx',
    'typescript',
    'vim',
    'vimdoc',
    'yaml'
  },
  sync_install = false,
  auto_install = true,
  highlight = { enable = true },
  additional_vim_regex_highlighting = false,
  disable = function(lang, buf)
      local max_filesize = 100 * 1024 -- 100 KB
      local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
      if ok and stats and stats.size > max_filesize then
          return true
      end
  end,
}
