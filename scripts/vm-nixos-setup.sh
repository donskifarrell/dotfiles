#!/bin/bash

set -e

echo "Setup bare NixOS. Press Enter"
while getopts 'h:' OPTION; do
    case "$OPTION" in
    h)
        HOSTNAME="$OPTARG"
        echo "Hostname: $HOSTNAME"
        ;;
    ?)
        echo "script usage: $(basename \$0) [-h <machine-hostname>]" >&2
        exit 1
        ;;
    esac
done
shift "$(($OPTIND - 1))"

read -r

# Generate Harware Config
sudo nixos-generate-config --root /mnt

# Copy in hardware config from generate step
sudo cp -v /mnt/etc/nixos/hardware-configuration.nix "/home/nixos/.dotfiles/hosts/${HOSTNAME}/hardware-configuration.nix"

# Installing System config
cd /home/nixos/.dotfiles
sudo nixos-install --no-root-passwd --flake ".#${HOSTNAME}"

printf "\rSystem setup done, reboot needed - eject the .iso first!\n"

read -r
