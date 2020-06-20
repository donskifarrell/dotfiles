# Replace 'ls' with exa if it is available.
if command -v exa >/dev/null 2>&1; then
    alias ls="exa --git --color=automatic"
    alias ll="exa --all --long --git --color=automatic"
    alias la="exa --all --binary --group --header --long --git --color=automatic"
    alias l="la"

    # Override `tree`
    # Note: you can append e.g `--level=5` to the end of the command to define a better depth
    alias tree="exa --all --tree --long --color=automatic --level=2"
fi
