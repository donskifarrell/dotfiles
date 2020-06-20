#!/bin/sh

# Symlink the .ssh configuration directory
if [[ ! -d "$HOME/.ssh" ]]; then
  if [[ ! -d "$HOME/Dropbox/sync/.ssh" ]]; then
    echo -e "\033[0;33mWARN: \033[1m$HOME/Dropbox/sync/.ssh\033[0m does not exist! Sync Dropbox.\033[1;34m"
  else
    ln -s -v "$HOME/Dropbox/sync/.ssh" "$HOME/.ssh"
    echo -e "Symlinked \033[1m$HOME/Dropbox/sync/.ssh\033[0m => \033[1m$HOME/.ssh\033[0m"

    sudo chmod 600 ~/.ssh/*
    sudo chmod 644 ~/.ssh/known_hosts
    sudo chmod 755 ~/.ssh
    echo -e "Set permissions on .SSH folder"
  fi
else
  echo -e "\033[0;33mWARN: \033[1m$HOME/.ssh\033[0m already exists. Please remove it and install again.\033[1;34m"
fi

test -L ~/.ssh/config || {
	mv ~/.ssh/config ~/.ssh/config.local
	ln -s "$DOTFILES"/ssh/config ~/.ssh/config
}
test -f ~/.ssh/config.local || touch ~/.ssh/config.local
