if empty(v:servername) && exists('*remote_startserver')
    call remote_startserver('VIM')
endif

let g:vimtex_grammar_textidote = {
            \ 'jar': '/opt/textidote/textidote.jar',
            \ 'args': '--check en'
            \}

if !exists('g:ycm_semantic_triggers')
    let g:ycm_semantic_triggers = {}
endif

let g:vimtex_view_method = 'zathura'
let g:vimtex_compiler_progname = 'nvr'
let g:vimtex_quickfix_enabled = 0
autocmd FileType tex setlocal spell
nnoremap <localleader>lt :call vimtex#fzf#run('ctl', g:fzf_layout)<cr>
