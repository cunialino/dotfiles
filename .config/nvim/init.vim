mapclear
:"i

let &t_ZM = "\e[3m"

" vim-plugs
call plug#begin('~/.local/share/nvim/plugged')
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'

Plug 'lervag/vimtex'

Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-fugitive'

Plug 'godlygeek/tabular'
Plug 'lambdalisue/vim-manpager'
Plug 'scrooloose/nerdtree'

Plug 'mattboehm/vim-unstack'
Plug 'mattboehm/vim-accordion'
"Plug 'airblade/vim-gitgutter'
Plug 'rhysd/conflict-marker.vim'

Plug 'ron89/thesaurus_query.vim'

Plug 'preservim/tagbar'

Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'dense-analysis/ale'

Plug 'SirVer/ultisnips'

Plug 'honza/vim-snippets'

Plug 'jalvesaq/Nvim-R', {'brach': 'stable'}

Plug 'kassio/neoterm'

Plug 'andymass/vim-matchup'
Plug 'jiangmiao/auto-pairs'

Plug 'arcticicestudio/nord-vim'
Plug 'vim-airline/vim-airline'

Plug 'easymotion/vim-easymotion'

Plug 'ryanoasis/vim-devicons'
Plug 'xuyuanp/nerdtree-git-plugin'

Plug 'morhetz/gruvbox'
call plug#end()


"Code Formatting
"autocmd FileType c,cpp,proto,javascript AutoFormatBuffer clang-format

" rfmt: R source code formatter
"let rfmt_executable = '/home/elia/R/x86_64-pc-linux-gnu-library/4.0/rfmt/python/rfmt.py'
"map <C-I> :pyf /home/elia/R/x86_64-pc-linux-gnu-library/4.0/rfmt/python/rfmt_vim.py<cr>

" augroups
augroup indents
    autocmd!
    autocmd FileType less,css,html setlocal ts=2 sts=2 sw=2 expandtab
    autocmd FileType text,markdown setlocal expandtab
    autocmd FileType python setlocal ts=4 sts=4 sw=4 expandtab
augroup END

augroup highlight_follows_vim
    autocmd!
    autocmd FocusGained * set cursorline
    autocmd FocusLost * set nocursorline
augroup END

augroup restorecursor
    autocmd BufReadPost *
                \ if line("'\"") > 1 && line("'\"") <= line("$") |
                \   execute "normal! g`\"" |
                \ endif
augroup END

" general settings
set nobackup
set nowritebackup
set noswapfile " get rid of swap files everywhere
set dir=/tmp

syntax on
autocmd FileType r setlocal omnifunc=
"set omnifunc=syntaxcomplete#Complete
"set completefunc=LanguageClient#complete
"set spell
set list
filetype indent on
set laststatus=2
set wrap
set noshowmode
set listchars=tab:???\ ,nbsp:???,trail:???,extends:>,precedes:<
set fillchars=vert:\???
set ignorecase
set smartcase
set sidescroll=40
set incsearch
set hlsearch
set undofile
set undodir=~/Documents/Neovim
set path+=**
set inccommand=split
set backspace=indent,eol,start
set hidden
set wildmenu
set foldmethod=manual
set complete=.,w,b,i,u,t,
set background=dark
set mouse=a
set number

set textwidth=78

set clipboard+=unnamedplus

set splitright
set splitbelow

set wildignore+=.git,.hg,.svn
set wildignore+=*.aux,*.out,*.toc
set wildignore+=*.o,*.obj,*.exe,*.dll,*.manifest,*.rbc,*.class
set wildignore+=*.ai,*.bmp,*.gif,*.ico,*.jpg,*.jpeg,*.png,*.psd,*.webp
set wildignore+=*.avi,*.divx,*.mp4,*.webm,*.mov,*.m2ts,*.mkv,*.vob,*.mpg,*.mpeg
set wildignore+=*.mp3,*.oga,*.ogg,*.wav,*.flac
set wildignore+=*.eot,*.otf,*.ttf,*.woff
set wildignore+=*.doc,*.pdf,*.cbr,*.cbz
set wildignore+=*.zip,*.tar.gz,*.tar.bz2,*.rar,*.tar.xz,*.kgb
set wildignore+=*.swp,.lock,.DS_Store,._*



set shiftwidth=4     " indent = 4 spaces
set expandtab
set tabstop=4        " tab = 4 spaces
set softtabstop=4    " backspace through spaces


function! GitBranch()
    return system("git rev-parse --abbrev-ref HEAD 2>/dev/null | tr -d '\n'")
endfunction

" Functions
function! GetTabber()  " a lil function that integrates well with Tabular.vim
    let c = nr2char(getchar())
    :execute 'Tabularize /' . c
endfunction



let g:help_in_tabs = 0
nmap <silent> H  :let g:help_in_tabs = !g:help_in_tabs <cr>

" Only apply to .txt files...
augroup HelpInTabs
    autocmd!
    autocmd BufEnter  *.txt   call HelpInNewTab()
augroup END

" Only apply to help files...
function! HelpInNewTab ()
    if &buftype == 'help' && g:help_in_tabs
        "Convert the help window to a tab...
        execute "normal \<C-W>T"
    endif
endfunction


"let g:transparent = 1
"function! ToggleTransparent()
"    if g:transparent == 0
"        hi Normal ctermbg = NONE
"        let g:transparent = 1
"    else
"        hi Normal ctermbg = black
"        let g:transparent = 0
"    endif
"endfunction

" mappings
let mapleader=' '


" nnoremap

:command! WQ wq
:command! Wq wq
:command! Wqa wqa
:command! W w
:command! Q q

" abbreviations
abclear
iab #i #include
iab #d #define
cab dst put =strftime('%d %a, %b %Y')<cr>
cab vg vimgrep


" emmet
let g:user_emmet_mode='a'
let g:user_emmet_leader_key='<C-X>'

" gitgutter
let g:gitgutter_override_sign_column_highlight = 0
let g:gitgutter_sign_added                     = '+'
let g:gitgutter_sign_modified                  = '??'
let g:gitgutter_sign_removed                   = '-'
let g:gitgutter_sign_removed_first_line        = '??'
let g:gitgutter_sign_modified_removed          = '??'


" indentLine
let g:indentLine_setColors = 0
let g:indentLine_char      = '???'

" keysound
let g:keysound_enable = 1
let g:keysound_volume = 1000
let g:keysound_py_version = 3
let g:keysound_theme = 'typewriter'



source ~/.config/nvim/src/Tagbar.vim
source ~/.config/nvim/src/mapping.vim
source ~/.config/nvim/src/NERDTree.vim
source ~/.config/nvim/src/UTSNIP.vim
source ~/.config/nvim/src/vimtex.vim
source ~/.config/nvim/src/fzf.vim
source ~/.config/nvim/src/nvimr.vim
source ~/.config/nvim/src/AirLine.vim
source ~/.config/nvim/src/coc.vim
source ~/.config/nvim/src/ale.vim
source ~/.config/nvim/src/thesaurus.vim

"Setting up colors
colorscheme gruvbox
"hi CursorLine ctermbg=none
"hi EndOfBuffer ctermbg=none
"hi NERDTreeFlags ctermfg=1
"hi NERDTreeClosable ctermfg=1
"hi NERDTreeOpenable ctermfg=2
""hi Comment ctermfg = red
"hi PrimaryBlock ctermfg=03 ctermbg=00
"hi SecondaryBlock ctermfg=03 ctermbg=00
"hi Blanks ctermfg=03 ctermbg=00

"neoterm
let g:neoterm_default_mod = 'tab'

augroup quickfix
    autocmd!
    autocmd FileType qf setlocal wrap
augroup END
