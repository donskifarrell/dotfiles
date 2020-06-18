# Replace 'ls' with exa if it is available.
if command -v exa >/dev/null 2>&1; then
    alias ls="exa --git --color=automatic"
    alias ll="exa --all --long --git --color=automatic"
    alias la="exa --all --binary --group --header --long --git --color=automatic"
    alias l="la"
fi