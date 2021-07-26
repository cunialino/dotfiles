set nocompatible
let g:airline#extensions#tabline#enabled = 1

filetype plugin indent on
syntax enable
set background=dark
let g:airline_powerline_fonts=1
"let g:airline_left_sep = "\uE0C6"
"let g:airline_right_sep =  "\UE0C7"
"let g:airline_left_alt_sep = "\uE0D4"
"let g:airline_right_alt_sep = "\uE0D2"
" set the CN (column number) symbol:
let g:airline_section_z = airline#section#create(["%p%% " . "\uE0A1" . '%{line(".")}' . "\uE0A3" . '%v'])
"let g:airline#extensions#tabline#alt_sep = 1
"let g:airline#extensions#ycm#enabled = 1
"let g:airline#extensions#fzf#enabled = 1
let g:airline_theme='gruvbox'
