#!/bin/bash

set -e

echo "Ensure NixOS config and home-manager are setup. Press Enter"
while getopts 'h:u:' OPTION; do
    case "$OPTION" in
    h)
        TARGET_HOSTNAME="$OPTARG"
        echo "Hostname: $TARGET_HOSTNAME"
        ;;
    u)
        USERNAME="$OPTARG"
        echo "Username: $USERNAME"
        ;;
    ?)
        echo "script usage: $(basename \$0) [-h <machine-hostname>] [-u <home-username>]" >&2
        exit 1
        ;;
    esac
done
shift "$(($OPTIND - 1))"

read -r

nix --version
echo $NIX_PATH

# Fix command-not-found
nix-channel --add https://nixos.org/channels/nixos-unstable nixos
nix-channel --update
printf "\rUpdated nix-channel \n"
nix-channel --list

# Fix command-not-found, but for root
sudo nix-channel --add https://nixos.org/channels/nixos-unstable nixos
sudo nix-channel --update
printf "\rUpdated nix-channel \n"
nix-channel --list

# Fix missing home-manager
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
printf "\rUpdated nix-channel \n"
nix-channel --list

hm=$(which home-manager)
if [ -z $hm ]; then
    printf "\rInstalling home-manager\n"
    nix-shell '<home-manager>' -A install # Note: you may need to logout and back in again
else
    printf "\rhome-manager found already\n"
fi

# Look for ~/.nix-defexpr/channels
echo $NIX_PATH

# Avoid conflict. It shoud be empty
if [ -f "/home/df/.config/fish/config.fish" ]; then
    printf "\rRemoving existing fish config\n"
    rm -v /home/df/.config/fish/config.fish
else
    printf "\rNo existing fish config found\n"
fi

# Installing
cd /home/$USERNAME/.dotfiles

printf "\rhome-manager version: \n"
home-manager --version
home-manager switch --flake ".#$USERNAME@$TARGET_HOSTNAME"

printf "\rEnvironment configured, reboot just to be sure. \n"

read -r
