
"=============================================================================
" dark_powered.vim --- Dark powered mode of SpaceVim
" Copyright (c) 2016-2017 Wang Shidong & Contributors
" Author: Wang Shidong < wsdjeg at 163.com >
" URL: https://spacevim.org
" License: GPLv3
"=============================================================================

set term=screen-256color
let g:spacevim_filemanager = 'nerdtree'

" SpaceVim Options: {{{
let g:spacevim_enable_debug = 1
let g:spacevim_realtime_leader_guide = 1
let g:spacevim_enable_tabline_filetype_icon = 1
let g:spacevim_enable_statusline_display_mode = 0
let g:spacevim_enable_os_fileformat_icon = 1
let g:spacevim_buffer_index_type = 1
let g:spacevim_enable_vimfiler_welcome = 1
let g:spacevim_enable_debug = 1
" }}}

map <Esc>OP <F1>
map <Esc>OQ <F2>
map <Esc>OR <F3>
map <Esc>OS <F4>
map <Esc>[16~ <F5>
map <Esc>[17~ <F6>
map <Esc>[18~ <F7>
map <Esc>[19~ <F8>
map <Esc>[20~ <F9>
map <Esc>[21~ <F10>
map <Esc>[23~ <F11>
map <Esc>[24~ <F12>
" SpaceVim Layers: {{{

call SpaceVim#layers#load('tags')
call SpaceVim#layers#load('cscope')
call SpaceVim#layers#load('lang#python')
call SpaceVim#layers#load('lang#javascript')
call SpaceVim#layers#load('lang#json')
call SpaceVim#layers#load('lang#tmux')
call SpaceVim#layers#load('lang#xml')
call SpaceVim#layers#load('lang#c')
call SpaceVim#layers#load('lang#markdown')
call SpaceVim#layers#load('lang#vim')
call SpaceVim#layers#load('lang#html')
call SpaceVim#layers#load('lang#sh')
call SpaceVim#layers#load('shell',
        \ {
        \ 'default_position' : 'top',
        \ 'default_height' : 30,
        \ }
        \ )
call SpaceVim#layers#load('git')
" }}}


