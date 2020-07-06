#!/bin/sh

mkdir -p "$HOME"/.nano/backups

if [ ! -d "$HOME"/.nano/syntax_improved ] 
then
    NANO_EXTRA="https://github.com/scopatz/nanorc"
    git clone --depth=1 $NANO_EXTRA "$HOME"/.nano/syntax_improved
fi
