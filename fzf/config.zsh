#!/bin/sh

export FZF_DEFAULT_COMMAND="fd --hidden --follow --exclude '.git' --exclude 'node_modules'"

export FZF_DEFAULT_OPTS="
--layout=reverse
--border
--info=inline
--multi
--preview '([[ -f {} ]] && (bat --style=numbers --color=always --line-range :500 {} || cat {})) || ([[ -d {} ]] && (exa --all --tree --long --color=always --level=1 {} | less)) || echo {} 2> /dev/null | head -200'
--pointer='▶' --marker='✓'
--bind '?:toggle-preview'
"
