#!/bin/sh

# Check out /exa
# if [ "$(uname -s)" = "Darwin" ]; then
# 	alias ls="ls -FG"
# else
# 	alias ls="ls -F --color"
# fi
# alias l="ls -lAh"
# alias la="ls -A"
# alias ll="ls -l"

alias reload!='exec "$SHELL" -l'
alias grep="grep --color=auto"
alias duf="du -sh * | sort -hr"
alias less="less -r"
alias cat="bat"
alias top="sudo htop"
alias help='tldr'

alias cdr='cd "$(git rev-parse --show-toplevel)"'
alias ..='cd ..'

# quick hack to make watch work with aliases
alias watch='watch -c -d -t '

# open, pbcopy and pbpaste on linux
if [ "$(uname -s)" != "Darwin" ]; then
	if [ -z "$(command -v pbcopy)" ]; then
		if [ -n "$(command -v xclip)" ]; then
			alias pbcopy="xclip -selection clipboard"
			alias pbpaste="xclip -selection clipboard -o"
		elif [ -n "$(command -v xsel)" ]; then
			alias pbcopy="xsel --clipboard --input"
			alias pbpaste="xsel --clipboard --output"
		fi
	fi
	if [ -e /usr/bin/xdg-open ]; then
		alias open="xdg-open"
	fi
fi

# like normal z when used with arguments but displays an fzf prompt when used without.
unalias z 2> /dev/null
z() {
    [ $# -gt 0 ] && _z "$*" && return
    cd "$(_z -l 2>&1 | fzf --height 40% --nth 2.. --reverse --inline-info --preview="echo {} | sed 's/^[0-9,.]* *//' | xargs exa --all --tree --color=always --level=1" +s --tac --query "${*##-* }" | sed 's/^[0-9,.]* *//')"
}
