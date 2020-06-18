#!/bin/sh

# Basic way to enable completion
# source "$HOME/.google-cloud-sdk/completion.zsh.inc"

# Lazy load as it slows down terminal start
function gcloud() {
    if ! type __start_gcloud >/dev/null 2>&1; then
        source "$HOME/.google-cloud-sdk/completion.zsh.inc"
    fi

    command gcloud "$@"
}