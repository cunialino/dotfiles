nmap <F10> <Plug>(ale_fix)
let g:ale_fixers = {
            \ 'python': ['yapf'],
            \ 'r': ['styler'],
            \ 'tex': ['latexindent', 'textlint'],
            \ '*': ['remove_trailing_lines', 'trim_whitespace']
            \ }
let g:ale_sign_style_error = ''
let g:ale_sign_style_warning = ''
let g:ale_sign_error = ''
let g:ale_sign_warning = ''
let g:ale_sign_info = ''
let g:ale_r_lintr_options='lintr::with_defaults(object_name_linter = NULL)'
let g:ale_linters_ignore = {
        \ 'cpp': ['cc', 'clangtidy'],
      \   'r': ['languageserver'],
      \}
let g:ale_echo_msg_error_str = ''
let g:ale_echo_msg_warning_str = ''
let g:ale_echo_msg_info_str = ''
let g:ale_echo_msg_format = '%severity% | %linter% : %s'
hi! def link ALEInfo Normal

let g:ale_linters = {
    \ 'python': ['pylint'],
    \ 'vim': ['vint'],
    \ 'cpp': ['clang'],
    \ 'c': ['clang'],
    \ 'markdown': ['languagetool']
\}

nnoremap <Leader>an :ALENextWrap<cr>
nnoremap <Leader>ap :ALEPreviousWrap<cr>
nnoremap <Leader>ad :ALEDetail<cr>
nnoremap <Leader>af :ALEFirst<cr>
