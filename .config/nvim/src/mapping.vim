"Lets you out of insert mode in terminal
tnoremap <Esc> <C-\><C-n>

nnoremap <Leader>o : only<cr>
nnoremap <Leader>t : call GetTabber()<cr>
nnoremap <F3>      : call ToggleTransparent()<cr>
nnoremap <Leader><ESC> : nohlsearch<cr>
nnoremap <F2>      : NERDTreeToggle<cr>
nnoremap <C-l> :nohlsearch<cr>:diffupdate<cr>:syntax sync fromstart<cr><c-l>

cmap w!! %!sudo tee > /dev/null %

"nmap <Leader>s <Plug>(easymotion-sn)
map <F4> :CondaChangeEnv<CR>

" vnoremap
vnoremap > >gv
vnoremap < <gv

" onoremap
onoremap ax a`
onoremap ix i`

" xnoremap
xnoremap + g<C-a>
xnoremap - g<C-x>
"Resize window, mainly done this for matlab interpreter
nnoremap <silent> <Leader>+ :exe "resize +5"<CR>
nnoremap <silent> <Leader>- :exe "resize -5"<CR>

"let you swap 2 windows

function! MarkWindowSwap()
    let g:markedWinNum = winnr()
endfunction

function! DoWindowSwap()
    "Mark destination
    let curNum = winnr()
    let curBuf = bufnr( "%" )
    exe g:markedWinNum . "wincmd w"
    "Switch to source and shuffle dest->source
    let markedBuf = bufnr( "%" )
    "Hide and open so that we aren't prompted and keep history
    exe 'hide buf' curBuf
    "Switch to dest and shuffle source->dest
    exe curNum . "wincmd w"
    "Hide and open so that we aren't prompted and keep history
    exe 'hide buf' markedBuf
endfunction

noremap <silent> <leader>mw :call MarkWindowSwap()<CR>
noremap <silent> <leader>pw :call DoWindowSwap()<CR>

