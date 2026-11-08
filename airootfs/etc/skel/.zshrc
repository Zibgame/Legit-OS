# ~/.zshrc optimisé et réorganisé

############################################################
# 1. PATH & VARIABLES
############################################################
export PATH="$HOME/.local/bin:$HOME/.local/node/bin:$HOME/.local/node/node-v22/bin:$HOME/.local/kitty.app/bin:$HOME/.npm-global/bin:$PATH"
export LANG="en_US.UTF-8"
export MAIL="zcadinot@student.42lehavre.fr"

path=(${(u)path})

############################################################
# 3. OH-MY-ZSH (partiel)
############################################################
export ZSH="/usr/share/oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)

autoload -Uz compinit && compinit
zstyle ':completion:*' rehash true
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
setopt correct autocd
unsetopt beep

if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi

unalias gup 2>/dev/null
unalias glog 2>/dev/null

############################################################
# 4. OPTIONS SHELL
############################################################
bindkey -v
stty -ixon
setopt extendedglob
setopt histignoredups sharehistory incappendhistory
HISTSIZE=50000
SAVEHIST=50000

############################################################
# 5. PROMPT
############################################################
autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats '(%b)'

PROMPT='%F{blue}💤%f %F{white}%~ %F{yellow}$vcs_info_msg_0_%f %F{blue}→%f %(?.%F{green}.%F{red})●%f '

############################################################
# 6. FONCTIONS 42 & DEV
############################################################
gup() {
  local pause=0.4 step=1 msg suggested
  clear
  echo "──────────────────────────────────────────────────────────"
  echo "  🚀  gup — Smart add → commit → push"
  echo "──────────────────────────────────────────────────────────"
  echo
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌  Pas un repo git."
    return 1
  fi
  local last_change
  last_change=$(git status --short | head -n 1)
  if [ -z "$last_change" ]; then
    suggested="Update project"
  else
    local code=$(echo "$last_change" | awk '{print $1}')
    local file=$(echo "$last_change" | awk '{print $2}')
    case "$code" in
      M) suggested="Update $file" ;;
      A) suggested="Create $file" ;;
      D) suggested="Delete $file" ;;
      R) suggested="Rename $file" ;;
      *) suggested="Update project" ;;
    esac
  fi
  read "msg?💬 Commit (ENTER = suggestion « $suggested ») : "
  [ -z "$msg" ] && msg="$suggested"
  step_echo() {
    printf "\n\033[1;34mÉtape %d\033[0m — %s\n" "$step" "$1"
    step=$((step + 1))
  }
  step_echo "git add ."
  git add .
  step_echo "git commit"
  git commit -m "$msg"
  step_echo "git push"
  git push
  echo "\n✅ Terminé."
}

norm() {
  echo "📏 Norminette…"
  norminette | sed 's/Error/❌ Error/g; s/Warning/⚠️ Warning/g'
}

runc() {
  if [[ -z "$1" ]]; then echo "Usage : runc file.c"; return; fi
  cc -Wall -Wextra -Werror "$@" -o a.out && ./a.out
}

cwarn() {
  if [[ -z "$1" ]]; then echo "Usage : cwarn file.c"; return; fi
  cc -Wall -Wextra -Werror -fsanitize=address -g "$1" -o a.out && ./a.out
}

glog() {
  git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(green)%an%C(reset) %C(yellow)%d%C(reset)%n%C(white)%s%C(reset)' --all
}

gitclean() {
  git branch --merged | grep -v main | grep -v master | xargs -r git branch -d
}

proj() {
  mkdir -p "$1"/src "$1"/include "$1"/build
  cat > "$1/Makefile" <<EOF
NAME = $1
SRC = src/main.c
OBJ = \$(SRC:.c=.o)
CC = cc
CFLAGS = -Wall -Wextra -Werror -Iinclude
all: \$(NAME)
\$(NAME): \$(OBJ)
	\$(CC) \$(CFLAGS) -o \$@ \$^
clean:
	rm -f \$(OBJ)
fclean: clean
	rm -f \$(NAME)
re: fclean all
EOF
  echo "int main() { return 0; }" > "$1/src/main.c"
  echo "Projet créé : $1/"
}

clip() {
  if [ -z "$1" ]; then echo "Usage : clip <file>"; return 1; fi
  if [ ! -f "$1" ]; then echo "❌ Fichier introuvable : $1"; return 1; fi
  if command -v wl-copy >/dev/null 2>&1; then wl-copy < "$1" && echo "📋 Copié avec wl-copy" && return 0; fi
  if command -v xclip >/dev/null 2>&1; then xclip -selection clipboard < "$1" && echo "📋 Copié avec xclip" && return 0; fi
  if [ -n "$TMUX" ] && command -v tmux >/dev/null 2>&1; then tmux load-buffer "$1" >/dev/null 2>&1 && echo "📋 Copié buffer tmux" && return 0; fi
  local esc=$'\033' bel=$'\007' size=4096
  local b64=$(base64 < "$1" | tr -d '\n') len=${#b64} i=0 chunk
  while [ $i -lt $len ]; do
    chunk=${b64:$i:$size}
    printf '%b]52;c;%s%b' "$esc" "$chunk" "$bel"
    i=$(( i + size ))
  done
  echo "📋 Copie via OSC52"
}

f() { find . -iname "*$1*" 2>/dev/null; }

############################################################
# 7. ALIASES
############################################################
alias fcc='cc -Wall -Werror -Wextra '
alias ll='ls -la'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias rm='rm -i'
alias cl='clear'

alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gco='git checkout'
alias gb='git branch'

alias nbl='find . -type f \( -name "*.c" -o -name "*.h" -o -name "Makefile" \) -exec wc -l {} +'

# Perso dev
alias francinette="$HOME/francinette/tester.sh"
alias paco="$HOME/francinette/tester.sh"
alias dev='cd ~ && cd Documents && clear && ls'
[[ -x /home/zcadinot/.local/bin/cleaner ]] && /home/zcadinot/.local/bin/cleaner

