#!/bin/sh

# Basic way to enable completion
# source <(jira --completion-script-zsh)

# Lazy load as it slows down terminal start
function jira() {
    if ! type __start_jira >/dev/null 2>&1; then
        source <(jira --completion-script-zsh)
    fi

    command jira "$@"
}
