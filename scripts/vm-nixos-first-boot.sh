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

# Fix command-not-found
nix-channel --add https://nixos.org/channels/nixos-unstable nixos
nix-channel --update

# Fix command-not-found, but for root
sudo nix-channel --add https://nixos.org/channels/nixos-unstable nixos
sudo nix-channel --update

# Fix missing home-manager
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
nix-shell '<home-manager>' -A install # Note: you may need to logout and back in again

nix-channel --list

# Look for ~/.nix-defexpr/channels
echo $NIX_PATH

# Avoid conflict. It shoud be empty
rm -v /home/df/.config/fish/config.fish

# Installing
cd /home/$USERNAME/.dotfiles

home-manager --version
home-manager switch --flake ".#$USERNAME@$TARGET_HOSTNAME"

printf "\rEnvironment configured, reboot just to be sure. \n"

read -r
