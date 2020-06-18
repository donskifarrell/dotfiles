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