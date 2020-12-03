set nocompatible
filetype off

call plug#begin('~/.vim/plugged')
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'SirVer/ultisnips'
Plug 'easymotion/vim-easymotion'
Plug 'terryma/vim-multiple-cursors'
Plug 'vim-airline/vim-airline'
Plug 'w0rp/ale'
Plug 'airblade/vim-gitgutter'
call plug#end()

filetype plugin indent on

" FZF configuration
nmap <C-p> :FZF<CR>
imap <C-p> <C-o>:FZF<CR>


" Ultisnipts configuration
" Trigger configuration. You need to change this to something other than <tab> if you use one of the following:
" - https://github.com/Valloric/YouCompleteMe
" - https://github.com/nvim-lua/completion-nvim
let g:UltiSnipsExpandTrigger="<tab>"
let g:UltiSnipsJumpForwardTrigger="<c-b>"
let g:UltiSnipsJumpBackwardTrigger="<c-z>"

" If you want :UltiSnipsEdit to split your window.
let g:UltiSnipsEditSplit="vertical"

filetype plugin on
syntax on
filetype plugin indent on
set modelines=0
set number
set visualbell
set ruler
set encoding=utf-8
set wrap
set textwidth=128
set formatoptions=tcqrn1
set tabstop=4
set shiftwidth=4
set expandtab
imap <C-j> <C-o>j
imap <C-k> <C-o>k
imap <C-h> <C-o>h
imap <C-l> <C-o>l
set showmode
set showcmd
set hlsearch
set incsearch
set ignorecase
set smartcase
set showmatch
set listchars=trail:·,nbsp:⎵,eol:¬,tab:▸\ ,extends:>,precedes:<
set list
set matchpairs+=<:>
nmap ; :
set hidden
set wildmenu
set wildignore+=**/node_modules/**
set wildignore+=*.pyc
set wildignore+=*.o

