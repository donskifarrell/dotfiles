#!/bin/bash

set -e

echo 'Creating various disk paritions and setting up filesystems. Press Enter'
printf "\rNote - run this as root\n"
printf "\rNote - assumes vda is the mounted disk volume name\n"
printf "\rNote - sometimes mounting boot fails!\n"

read

# UEFI (GPT)
printf "\UEFI - \n"
parted /dev/vda -- mklabel gpt
parted /dev/vda -- mkpart primary 512MiB -8GiB
parted /dev/vda -- mkpart primary linux-swap -8GiB 100%
parted /dev/vda -- mkpart ESP fat32 1MiB 512MiB
parted /dev/vda -- set 3 esp on

# Formatting
printf "\Formatting - \n"
mkfs.ext4 -L nixos /dev/vda1
mkswap -L swap /dev/vda2
mkfs.fat -F 32 -n boot /dev/vda3

# Mounting
printf "\Mounting - \n"
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
swapon /dev/vda2

printf "\rDone\n"
