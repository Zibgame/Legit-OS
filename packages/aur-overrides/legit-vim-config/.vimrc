" **************************************************************************** "
"                                                                              "
"                                                         :::      ::::::::    "
"    .vimrc                                             :+:      :+:    :+:    "
"                                                     +:+ +:+         +:+      "
"    By: zcadinot <zcadinot@student.42.fr>          +#+  +:+       +#+         "
"                                                 +#+#+#+#+#+   +#+            "
"    Created: 2025/10/14 21:50:23 by zcadinot          #+#    #+#              "
"    Updated: 2025/10/14 21:50:28 by zcadinot         ###   ########.fr        "
"                                                                              "
" **************************************************************************** "

" =======================
" ⚙️ Options générales
" =======================
set nocompatible               " Mode non compatible vi, pour utiliser Vim complet
filetype plugin indent on      " Activation des plugins et indent automatique selon le type de fichier
syntax on                      " Activation de la coloration syntaxique
set mouse=a                    " Souris active partout (normal, insert, visual...)
set clipboard=unnamedplus      " Utiliser le presse-papiers système
set termguicolors              " Couleurs 24-bit si terminal supporte
set noshowmode                 " Désactive le message -- INSERT -- natif
set encoding=UTF-8             " Encodage UTF-8
set cmdheight=1
set laststatus=2
set tabstop=4
set shiftwidth=4
set expandtab     " si tu veux convertir tab → espaces

" =======================
" 👤 Variables personnelles
" =======================
let g:user42 = 'zcadinot'
let g:mail42 = 'zcadinot@student.42.fr'

" =======================
" 🔌 Plugins avec vim-plug
" =======================
call plug#begin('~/.vim/plugged')

" 🎨 Thèmes
Plug 'morhetz/gruvbox'
Plug 'dracula/vim'
Plug 'bluz71/vim-moonfly-colors'
Plug 'flazz/vim-colorschemes'

" 🧩 Icônes
Plug 'ryanoasis/vim-devicons'

" 📁 Explorateur de fichiers
Plug 'preservim/nerdtree'

" 📊 Barre de statut
Plug 'itchyny/lightline.vim'
"Plug 'dracula/lightline'

" 🧠 Gestion de code
Plug 'tpope/vim-surround'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-fugitive'
Plug 'preservim/nerdcommenter'

" 🧬 Syntaxe améliorée
Plug 'sheerun/vim-polyglot'

" 🤖 Autocomplétion (désactivée pour l’instant)
" Plug 'neoclide/coc.nvim', {'branch': 'release'}

" 🌈 Plugins divers
Plug 'easymotion/vim-easymotion'
Plug 'mhinz/vim-startify'
" Plug 'psliwka/vim-smoothie'
Plug 'Zibgame/Vim-C_compiler'
Plug '42Paris/42header'

" Plug 'vim-syntastic/syntastic'
" Plug 'alexandregv/norminette-vim'
Plug 'vim-scripts/DoxygenToolkit.vim'


call plug#end()

" =======================
" 💡 Configuration Lightline
" =======================
let g:lightline = {
      \ 'colorscheme': 'dracula',
      \ 'active': {
      \   'left': [ [ 'mode', 'paste' ],
      \             [ 'gitbranch', 'filename', 'modified' ] ]
      \ },
      \ 'component_expand': {
      \   'gitbranch': 'fugitive#head'
      \ }
      \ }

set laststatus=2

" =======================
" 🎨 Thème par défaut
" =======================
colorscheme dracula

" =======================
" 🪄 Mappings rapides
" =======================
let mapleader = " "            " Espace comme touche leader

" Sortie rapide du mode insert
inoremap jk <Esc>
inoremap kj <Esc>

" Arbre de fichiers
nnoremap <C-n> :NERDTreeToggle<CR>

" Sauvegarde rapide
nnoremap <C-s> :w<CR>
inoremap <C-s> <Esc>:w<CR>a

" Undo rapide
nnoremap <C-z> :u<CR>
inoremap <C-z> <Esc>:u<CR>a

" =======================
" 🚀 EasyMotion
" =======================
nmap <Leader>f <Plug>(easymotion-bd-f)

" =======================
" 🏁 Startify (page d'accueil)
" =======================
let g:startify_custom_header = [
      \ '░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ ▒▓██████████████▓▒░  ',
      \ '░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ ▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ ',
      \ ' ░▒▓█▓▒▒▓█▓▒░░░▒▓█▓▒░ ▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ ',
      \ ' ░▒▓█▓▒▒▓█▓▒░░░▒▓█▓▒░ ▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ ',
      \ '  ░▒▓█▓▓█▓▒░  ░▒▓█▓▒░ ▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ ',
      \ '  ░▒▓█▓▓█▓▒░  ░▒▓█▓▒░ ▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ ',
      \ '   ░▒▓██▓▒░   ░▒▓█▓▒░ ▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░  ',
      \ '  ',
      \ '      [p] Plugins       [n] NERDTree'
      \ ]

let g:startify_lists = [
      \ { 'type': 'files',     'header': ['   Mes fichiers récents']       },
      \ { 'type': 'bookmarks', 'header': ['   Mes favoris']               },
      \ { 'type': 'sessions',  'header': ['   Mes sessions sauvegardées']},
      \ ]

let g:startify_custom = [
      \ { 'type': 'commands', 'header': ['   Raccourcis Utiles'], 'content': [
      \     {'c': 'NERDTreeToggle', 'd': 'Ouvrir / fermer NERDTree'},
      \     {'c': 'PlugStatus', 'd': 'Voir l’état des plugins'},
      \     {'c': 'CocList extensions', 'd': 'Lister extensions Coc'}
      \ ]}
      \ ]

" Raccourcis globaux
nnoremap <leader>m :call StartifyMenu()<CR>
nnoremap <leader>p :PlugStatus<CR>
nnoremap <leader>n :NERDTreeToggle<CR>

" Mappings spécifiques à Startify
augroup startify_mappings
  autocmd!
  autocmd FileType startify call StartifyMappings()
augroup END

function! StartifyMappings()
  nnoremap <buffer> p :PlugStatus<CR>
  nnoremap <buffer> n :NERDTreeToggle<CR>
endfunction

" =======================
" 🔧 Fonctions utilitaires
" =======================
function! CheckBackspace() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1] =~# '\s'
endfunction

" =======================
" 🌫️ Fond transparent (compatible Kitty)
" =======================
" Force le support 256 couleurs
set t_Co=256
set termguicolors

augroup TransparentBackground
  autocmd!
  " Appliqué automatiquement à chaque changement de couleurscheme
  autocmd ColorScheme * highlight Normal     ctermbg=NONE guibg=NONE
  autocmd ColorScheme * highlight NormalNC   ctermbg=NONE guibg=NONE
  autocmd ColorScheme * highlight SignColumn ctermbg=NONE guibg=NONE
  autocmd ColorScheme * highlight LineNr     ctermbg=NONE guibg=NONE
  autocmd ColorScheme * highlight Folded     ctermbg=NONE guibg=NONE
augroup END

" Application immédiate au lancement
highlight Normal     ctermbg=NONE guibg=NONE
highlight NormalNC   ctermbg=NONE guibg=NONE
highlight SignColumn ctermbg=NONE guibg=NONE
highlight LineNr     ctermbg=NONE guibg=NONE
highlight Folded     ctermbg=NONE guibg=NONE


" =======================
" Syntastic minimal + Norminette
" =======================

" Checker norminette + gcc
let g:syntastic_c_checkers = ['norminette', 'gcc']
let g:syntastic_aggregate_errors = 1

" Norminette
let g:syntastic_c_norminette_exec = 'norminette'
let g:syntastic_c_norminette_args = '-R CheckTopCommentHeader'

" Headers support
let g:c_syntax_for_h = 1
let g:syntastic_c_include_dirs = [
      \ 'include', '../include', '../../include',
      \ 'libft', '../libft/include', '../../libft/include'
      \ ]

" Check au chargement
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0

" Toujours remplir loclist mais NE PAS l’ouvrir automatiquement
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 0

" Pas de messages inline
let g:syntastic_enable_balloons = 0
let g:syntastic_echo_current_error = 0

" Gutter avec ✗
let g:syntastic_enable_signs = 1
let g:syntastic_error_symbol = '✗'
let g:syntastic_warning_symbol = '✗'
