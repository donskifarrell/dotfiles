#!/bin/sh

# Basic way to enable completion
# source <(kubectl completion zsh)

# Lazy load as it slows down terminal start
function kubectl() {
    if ! type __start_kubectl >/dev/null 2>&1; then
        source <(command kubectl completion zsh)
    fi

    command kubectl "$@"
}

# complete -F __start_kubectl k
# kcc() {
#     if [[ $# -eq 0 ]]; then
#         k config get-contexts
#     else
#         k config use-context $@
#     fi
# }
