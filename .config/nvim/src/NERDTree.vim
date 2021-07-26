"Open NERDTree in new tabs
"autocmd BufWinEnter * NERDTreeMirror
let NERDTreeMinimalUI = 1
let NERDTreeDirArrows = 1
let NERDTreeMinimalMenu = 1

"Close nerdtree if it's the last buffer open
augroup nerdtree
    autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
augroup END
let g:NERDTreeDirArrowExpandable = "\ue0ce "
let g:NERDTreeDirArrowCollapsible = "\ue0cf "
let NERDTreeNodeDelimiter = "\uf46e"
let NERDTreeStatusline = "%{getcwd()==$HOME?'\uf015  ':'\uf07c '}%-0.10{substitute(getcwd(), $HOME, '~', '')}"
let g:NERDTreeHighlightCursorline=0
"Remove root line
augroup nerdtreehidecwd
    autocmd!
    autocmd FileType nerdtree syntax match NERDTreeHideCWD #^[</].*$# conceal
augroup end
