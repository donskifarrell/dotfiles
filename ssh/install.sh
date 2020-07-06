#!/bin/sh

# Symlink the .ssh configuration directory
if [[ ! -d "$HOME/.ssh" ]]; then
  if [[ ! -d "$HOME/Dropbox/sync/.ssh" ]]; then
    echo "$HOME/Dropbox/sync/.ssh does not exist! Sync Dropbox."
  else
    ln -s -v "$HOME/Dropbox/sync/.ssh" "$HOME/.ssh"
    echo "Symlinked $HOME/Dropbox/sync/.ssh => $HOME/.ssh"

    sudo chmod 600 ~/.ssh/*
    sudo chmod 644 ~/.ssh/known_hosts
    sudo chmod 755 ~/.ssh
    echo "Set permissions on .SSH folder"
  fi
else
  echo "$HOME/.ssh already exists. Please remove it and install again."
fi

test -L ~/.ssh/config || {
	mv ~/.ssh/config ~/.ssh/config.local
	ln -s "$DOTFILES"/ssh/config ~/.ssh/config
}
test -f ~/.ssh/config.local || touch ~/.ssh/config.local
