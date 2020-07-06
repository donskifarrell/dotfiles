#!/bin/sh

if [ ! -d "$HOME"/.tmux/plugins/tpm ] 
then
    mkdir -p ~/.tmux/plugins/
    git clone git@github.com:tmux-plugins/tpm.git ~/.tmux/plugins/tpm
fi
