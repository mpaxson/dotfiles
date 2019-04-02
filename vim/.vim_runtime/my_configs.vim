set term=screen-256color
set background=dark
syntax enable
colorscheme gruvbox

set number
set foldmethod=syntax

"===================================="
"    Python Mode Configureation"
"===================================="
let g:pymode                    = 1
let g:pymode_version            = 'python3'
let g:pymode_options            = 1
let g:pymode_indent             = 1
let g:pymode_folding            = 1
let g:pymode_trim_whitespaces   = 1

"========== Compatibility ========"

set t_Co=256

"if has("termguicolors")
"        set termguicolors
"endif

"if match($TERM, "screen")!=-1
"  set term=xterm-256
"endif


"====           Mappings        "



"=====================================================
"==============     CTF FILE        ==================
"=====================================================
"
"autocmd bufnewfile exploit.py so ~/.vim_runtime/headers/ctf.txt
"autocmd bufwritepost,filewritepost exploit.py execute "normal `a"


