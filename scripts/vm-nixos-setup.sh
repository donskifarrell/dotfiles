#!/bin/bash

set -e

echo "Setup bare NixOS. Press Enter"
while getopts 'h:' OPTION; do
    case "$OPTION" in
    h)
        TARGET_HOSTNAME="$OPTARG"
        echo "Target Hostname: $TARGET_HOSTNAME"
        ;;
    ?)
        echo "script usage: $(basename \$0) [-h <machine-target-hostname>]" >&2
        exit 1
        ;;
    esac
done
shift "$(($OPTIND - 1))"

read -r

# Generate Harware Config
sudo nixos-generate-config --root /mnt

# Copy in hardware config from generate step
sudo cp -v /mnt/etc/nixos/hardware-configuration.nix "/home/nixos/.dotfiles/hosts/${TARGET_HOSTNAME}/hardware-configuration.nix"

# Installing System config
cd /home/nixos/.dotfiles
sudo nixos-install --no-root-passwd --flake ".#${TARGET_HOSTNAME}"

printf "\rSystem setup done, reboot needed - eject the .iso first!\n"

read -r
