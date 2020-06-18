#!/bin/sh
test -L ~/.tmux/plugins/tpm || {
    mkdir -p ~/.tmux/plugins/
    git clone git@github.com:tmux-plugins/tpm.git ~/.tmux/plugins/tpm
}
