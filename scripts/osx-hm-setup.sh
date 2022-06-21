#!/bin/bash

set -e

echo "Setup home-manager on OSX. Press Enter"
while getopts 'u:' OPTION; do
    case "$OPTION" in
    u)
        USERNAME="$OPTARG"
        echo "Username: $USERNAME"
        ;;
    ?)
        echo "script usage: $(basename \$0) [-u <home-username>]" >&2
        exit 1
        ;;
    esac
done
shift "$(($OPTIND - 1))"

echo "Make sure we are on the correct system config (rosetta processes will fake the arch as i386/x86_64)"
echo "Note - assuming we're on zsh shell initially"
uname -p
uname -m
nix --version
echo $SHELL
echo $USER

echo "Press Enter to continue"
read -r

# Make nixpkgs available
nix-channel --add https://channels.nixos.org/nixos-unstable nixpkgs
nix-channel --update
nix-channel --list

# Make home-manager installable
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
nix-channel --list

# Emable nix-command and flakes to bootstrap
mkdir -p ~/.config/nix
cp -v /etc/nix/nix.conf ~/.config/nix/nix.conf
echo "\n# Added via dotfile setup script\nexperimental-features = nix-command flakes" >>~/.config/nix/nix.conf

# Add fish shell to OSX allowed shells, then activate
echo "/Users/$USERNAME/.nix-profile/bin/fish" >>/etc/shells
cat /etc/shells

# For Go directories
[ ! -d ~/go/bin ] && mkdir -vp ~/go/bin
[ ! -d ~/go/pkg ] && mkdir -vp ~/go/pkg
[ ! -d ~/go/src ] && mkdir -vp ~/go/src

echo $NIX_PATH

# Install Brew and the apps
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
/opt/homebrew/bin/brew analytics off
/opt/homebrew/bin/brew bundle --file ~/.dotfiles/Brewfile

# Make sure we are getting the Alacritty terminfo set
cd ~/Downloads/
wget -v https://github.com/alacritty/alacritty/releases/download/v0.10.1/alacritty.info
sudo tic -e alacritty,alacritty-direct alacritty.info

# Apparently sets $NIX_PATH
source ~/.nix-profile/etc/profile.d/nix.sh

echo "Run 'nix-shell' next before installing home-manager"
echo "Done. Press Enter"

# Symlinks Nix applications folder to /Applications so it can be picked up by Alfred
ln -s ~/.nix-profile/Applications/Alacritty.app/ ./Alacritty.app
ln -s ~/.nix-profile/Applications/Visual\ Studio\ Code.app/ ./Visual\ Studio\ Code.app

# TODO: Run OSX default settings

read -r
