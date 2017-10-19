set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'

" The following are examples of different formats supported.
" Keep Plugin commands between vundle#begin/end.
" plugin on GitHub repo
"Plugin 'tpope/vim-fugitive'
" plugin from http://vim-scripts.org/vim/scripts.html
Plugin 'L9'
" Git plugin not hosted on GitHub
Plugin 'git://git.wincent.com/command-t.git'
" git repos on your local machine (i.e. when working on your own plugin)
"Plugin 'file:///home/gmarik/path/to/plugin'
" The sparkup vim script is in a subdirectory of this repo called vim.
" Pass the path to set the runtimepath properly.
"Plugin 'rstacruz/sparkup', {'rtp': 'vim/'}
" Install L9 and avoid a Naming conflict if you've already installed a
" different version somewhere else.
"Plugin 'ascenator/L9', {'name': 'newL9'}

Plugin 'scrooloose/nerdtree'
Plugin 'mileszs/ack.vim'
Plugin 'rking/ag.vim'
Plugin 'corntrace/bufexplorer'
Plugin 'ctrlpvim/ctrlp.vim'
Plugin 'vim-scripts/mayansmoke'
Plugin 'evanmiller/nginx-vim-syntax'
Plugin 'amix/open_file_under_cursor.vim'
Plugin 'scrooloose/snipmate-snippets'
Plugin 'vim-scripts/tlib'
Plugin 'MarcWeber/vim-addon-mw-utils'
Plugin 'sophacles/vim-bundle-mako'
Plugin 'kchmck/vim-coffee-script'
Plugin 'michaeljsmith/vim-indent-object'
Plugin 'groenewege/vim-less'
Plugin 'tpope/vim-markdown'
Plugin 'therubymug/vim-pyte'
Plugin 'garbas/vim-snipmate'
Plugin 'honza/vim-snippets'
Plugin 'tpope/vim-surround'
Plugin 'terryma/vim-expand-region'
Plugin 'terryma/vim-multiple-cursors'
Plugin 'tpope/vim-fugitive'
Plugin 'junegunn/goyo.vim'
Plugin 'amix/vim-zenroom2'
Plugin 'scrooloose/syntastic'
Plugin 'tpope/vim-repeat'
Plugin 'tpope/vim-commentary'
Plugin 'fatih/vim-go'
Plugin 'airblade/vim-gitgutter'
Plugin 'morhetz/gruvbox'
Plugin 'nvie/vim-flake8'
Plugin 'digitaltoad/vim-pug'
Plugin 'maxbrunsfeld/vim-yankstack'
Plugin 'octol/vim-cpp-enhanced-highlight'
Plugin 'tyrannicaltoucan/vim-quantum'
Plugin 'othree/html5.vim'
Plugin 'hdima/python-syntax'
Plugin 'klen/python-mode'

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required
" To ignore plugin indent changes, instead use:
"filetype plugin on
"
" Brief help
" :PluginList       - lists configured plugins
" :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
" :PluginSearch foo - searches for foo; append `!` to refresh local cache
" :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
"
" see :h vundle for more details or wiki for FAQ
" Put your non-Plugin stuff after this line
set term=screen-256color
set number
set foldmethod=syntax
set foldnestmax=5
set foldlevelstart=20

syntax enable
set background=dark
colorscheme quantum

"=======if on ssh======="

"Off if SSH"
"----------"
let g:quantum_italics = 1
let g:airline_theme='quantum'

"================================================"
"==========         Python      ================"
"================================================"
"Run python file by pressing f9"

autocmd FileType python nnoremap <buffer> <F9> :w <bar> :exec '!python' shellescape(@%, 1)<cr>

"    Python Mode Configureation"

let g:pymode                    = 1
let g:pymode_version            = 'python'
let g:pymode_options            = 1
let g:pymode_indent             = 1
let g:pymode_folding            = 1
let g:pymode_trim_whitespaces   = 1

"========== Compatibility ========"

set t_Co=256

if has("termguicolors")
        set termguicolors
endif



"=====================================================
"==============     CTF FILE        ==================
"=====================================================
autocmd bufnewfile exploit.py so ~/.vim_runtime/headers/ctf.txt




