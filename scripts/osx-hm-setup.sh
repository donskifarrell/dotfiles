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
echo "Note - assuming we're on zsh shell"
uname -p
uname -m
nix --version
echo $SHELL
echo $USER

echo "Press Enter to continue"
read -r

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
chsh -s /Users/$USERNAME/.nix-profile/bin/fish

# For Go directories
[ ! -d ~/go/bin ] && mkdir -vp ~/go/bin
[ ! -d ~/go/pkg ] && mkdir -vp ~/go/pkg
[ ! -d ~/go/src ] && mkdir -vp ~/go/src

# cat <<EOF >~/.config/nix/nix.conf
# build-users-group = nixbld
# experimental-features = nix-command flakes
# EOF

# mkdir -p ~/.local/config

# source ~/.zprofile
echo $NIX_PATH

# printf "Run \n\n     source ~/.zprofile \n\nafter exit"
echo "Done. Press Enter"

read -r
