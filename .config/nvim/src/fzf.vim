" fzf colors
nnoremap <Leader>z : FZF<cr>
nnoremap <Leader>b : Buffers<cr>
let g:fzf_layout = { 'window': { 'width': 0.5, 'height': 0.2 } }
let g:fzf_colors =
            \ { 'fg':      ['fg', 'Normal'],
            \ 'bg':      ['bg', 'Normal'],
            \ 'hl':      ['fg', 'Comment'],
            \ 'fg+':     ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
            \ 'bg+':     ['bg', 'CursorLine', 'CursorColumn'],
            \ 'hl+':     ['fg', 'Statement'],
            \ 'info':    ['fg', 'PreProc'],
            \ 'border':  ['fg', 'Ignore'],
            \ 'prompt':  ['fg', 'Conditional'],
            \ 'pointer': ['fg', 'Exception'],
            \ 'marker':  ['fg', 'Keyword'],
            \ 'spinner': ['fg', 'Label'],
            \ 'header':  ['fg', 'Comment'] }
let g:fzf_action = {
            \ 'ctrl-t': 'tab split',
            \ 'ctrl-x': 'split',
            \ 'ctrl-v': 'vsplit',
            \ 'ctrl-b': 'badd'}

function! FzfSpellSink(word)
  exe 'normal! "_ciw'.a:word
endfunction
function! FzfSpell()
  let suggestions = spellsuggest(expand("<cword>"))
  return fzf#run(fzf#wrap({'source': suggestions, 'sink': function("FzfSpellSink")}))
endfunction

function! FzfSynonim()
  let suggestions = thesaurus_query#Thesaurus_Query_Lookup_List(expand("<cword>")) 
  return fzf#run(fzf#wrap({'source': suggestions, 'sink': function("FzfSpellSink")}))
endfunction

nnoremap z= :call FzfSpell()<CR>

