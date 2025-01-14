# Dots

| Hostname       | Users | System         | What is it?         |
| -------------- | ----- | -------------- | ------------------- |
| abhaile (home) | df    | x86_64-linux   | Desktop workstation |
| iompar (carry) | df    | aarch64-darwin | M1 Macbook Pro      |
| TODO: qemu     | df    | x86_64-linux   | VM (multiple)       |

These dotfiles try to keep things easy and composable. Everything is driven from the base `flake.nix` using common tooling along with the https://flake.parts/ framework for some autowiring. Some liberal copying from https://github.com/srid/nixos-config and my own previous configs.

A general good resource is https://github.com/nix-community/awesome-nix and https://mynixos.com/

For configuration of Asus ROG Rapture GT-AX6000, look [here](./bin/asus-gt-ax6000/README.md)

## OSX Fresh Install

There are always some small manual tweak to do, but essentially a fresh install goes like:

```
# Basic utils
xcode-select --install

# If you are on Apple Silicon and want Rosetta2
# softwareupdate --install-rosetta

# Install standard Nix
sh <(curl -L https://nixos.org/nix/install)

# Make sure we are on the correct system config (rosetta processes will fake the arch as i386/x86_64)
uname -p # outputs: arm on M1, unkown on nixos
uname -m # outputs: arm64 on M1, x86_64 on nixos

# Check hostname is correct, if not, goto System Preferences and change it there
scutil --get LocalHostName

# Get the df@secrets.nix key and put in the .ssh folder
# `mkdir ~/.ssh` might be needed

# Manually download the dotfiles from this repo to the path ~/.dotfiles. We'll replace later
cd ~
wget -O .dotfiles.zip https://github.com/donskifarrell/dotfiles/archive/refs/heads/main.zip
unzip .dotfiles.zip

# We need to bootstrap the nix-darwin installer. I use flakes, so we need to use experimental flake commands
# Note: --impure flag is due to some configs like boot timestamp that I need to resolve still.
nix run --extra-experimental-features nix-command --extra-experimental-features flakes nix-darwin -- switch --flake ~/.dotfiles/#iompar --impure

# Once that installs, we can use the simpler command in the future (Alias it somewhere)
/run/current-system/sw/bin/darwin-rebuild switch --flake ~/.dotfiles/#iompar --impure

# Now you can delete the dotfiles and do a proper git clone
rm -rf ~/.dotfiles
git clone git@github.com:donskifarrell/dotfiles.git ~/.dotfiles
```

Post-install, there are still some additional steps:
(

1. Applications on OSX that still need a manual install:

   - Prey (OSX has some trouble installing) https://preyproject.com/download

2. Browser extension that needs to be installed manually:

   - Paywall bypass https://github.com/iamadamdev/bypass-paywalls-chrome
     - unzip to a folder: ~/.bypass-paywalls-chrome so it's out of the way (don't delete folder?)

3. Review nix-darwin options: https://daiderd.com/nix-darwin/manual/index.html

## TODO

### - Common

- Install tooling:
  - Syncthing
  - Podman (with alias for docker)
- Allow stable/unstable nixpkgs

### - Nixos

- DConf settings
- Create an iso image with base config already installed
- Install tooling:
  - OpenSnitch
- For dev VMs, use https://github.com/nix-community/nixos-vscode-server
- Add plymouth theme: https://github.com/adi1090x/plymouth-themes
- Media keys
- BIOS tweak (XMP; V.T on CPU)
- Enforce BT settings - A2DP sink/LDAC for headset

## Misc Links

https://nixos-and-flakes.thiscute.world/nixos-with-flakes/nixos-with-flakes-enabled#adding-custom-cache-mirrors

https://github.com/iamadamdev/bypass-paywalls-chrome

https://unix.stackexchange.com/questions/272660/how-to-split-etc-nixos-configuration-nix-into-separate-modules

https://github.com/schuelermine/xhmm

https://github.com/nix-community/nixpkgs-wayland#packages

https://github.com/malob/nixpkgs

https://github.com/mitchellh/nixos-config

https://github.com/chvp/nixos-config (check out SSH, Secrets)

https://github.com/Misterio77/nix-config

https://gist.github.com/ptrfrncsmrph/2d1646fbb035bd76cf8c691c0d5cf47f#file-flake-nix-L72

https://discourse.nixos.org/t/fixing-your-install-after-osx-upgrade/19339

http://ghedam.at/15978/an-introduction-to-nix-shell

https://jeffhandley.com/2021-01-09/family-email-setup
