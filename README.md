# My Dots

I've essentially got 3 machines:

| Hostname | Users | System         | What is it?             |
| -------- | ----- | -------------- | ----------------------- |
| makati   | df    | x86_64-linux   | Desktop workstation     |
| manila   | df    | aarch64-darwin | M1 Macbook Pro          |
| qemu     | df    | x86_64-linux   | VM (multiple)           |
| belfast  | N/A   | x86_64-linux   | Ubuntu(?) VPS - Not Nix |

These dotfiles try to keep things easy and composable. Everything is driven from the base `flake.nix` using standard tooling.

In `./hosts` you'll find the main configurations for each hostname above. Each config file will have system customisations as needed but the bulk of customisation is simply adding or omitting the relevant import module file.

Similarly for `home-manager`, each hostname config may have the odd customisation, but most of the selection is simply importing the relevant home-manager module.

For user packages, I put everything into `./hosts/home-manager/packages.nix` so it's easier to see what each system has at once.

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
nix run --extra-experimental-features nix-command --extra-experimental-features flakes nix-darwin -- switch --flake ~/.dotfiles/#manila --impure

# Once that installs, we can use the simpler command in the future (Alias it somewhere)
/run/current-system/sw/bin/darwin-rebuild switch --flake ~/.dotfiles/#manila --impure

# Now you can delete the dotfiles and do a proper git clone
rm -rf ~/.dotfiles
git clone git@github.com:donskifarrell/dotfiles.git ~/.dotfiles
```

## NIXOS Fresh Install

The nixos install is more involved, as it's an entire system.

```
# The easiest way is to use the GUI installer from an ISO: https://nixos.org/download.html#nixos-iso

# Get the df@secrets.nix key and put in the .ssh folder
# `mkdir ~/.ssh` might be needed

# Manually download the dotfiles from this repo to the path ~/.dotfiles. We'll replace later
cd ~
wget -O .dotfiles.zip https://github.com/donskifarrell/dotfiles/archive/refs/heads/main.zip
unzip .dotfiles.zip

# Once we have the dotfiles in the correct location
sudo nixos-rebuild --flake ~/.dotfiles/#makati switch --impure

# Nixos manual warns 23.11 may break boot mounts, so it's wise to re-run:
# sudo nixos-rebuild --flake ~/.dotfiles/#makati boot --impure

# Now you can delete the dotfiles and do a proper git clone
rm -rf ~/.dotfiles
git clone git@github.com:donskifarrell/dotfiles.git ~/.dotfiles
```

## TODO

### - Common

- ~~Integrate Aegnix for secrets: https://github.com/ryantm/agenix~~
- Integrate Lorri?: https://github.com/nix-community/lorri or https://github.com/nix-community/nix-direnv
- Install tooling:
  - Wireguard, or Tailscale
  - Syncthing
  - Docker, or Podman
  - Direnv
  - VMs: https://github.com/Mic92/nixos-shell
- How do I sync easily:
  - Brave: has a sync chain - way to "nix" it?
  - Vivaldi: has a sync feature - way to "nix" it?
  - Firefox: ?
  - fish-shell history
  - ~~.local git configs, and other things~~
- Allow stable/unstable nixpkgs
- Common scripts (backup, restore etc)
- Cleanup VSCode config - use symlink so it's easily editable

### - OSX

- Look at nix-darwin options: https://daiderd.com/nix-darwin/manual/index.html
- How do I sync easily:
  - LittleSnitch (OSX) ruleset: Can be copied, or symlinked to Dropbox?

Applications on OSX that still need manual install via App Store:

- Coin Tick - Menu Bar Crypto
- ColorSlurp
- Unsplash Wallpapers
- WireGuard
- Prey (OSX has some trouble installing)

Browser extension that needs to be installed manually:

- Paywall bypass https://github.com/iamadamdev/bypass-paywalls-chrome
  -- unzip to a folder: ~/.bypass-paywalls-chrome so it's out of the way (don't delete folder)

### - Nixos

- Integrate Flatpak / AppImage on Linux
- Create an iso image with base config already installed
- Install tooling:
  - OpenSnitch
- For dev VMs, use https://github.com/nix-community/nixos-vscode-server
- Switch to pop_os! DE?
- Add cron job to switch wallpapers: https://github.com/cronie-crond/cronie
- ROFI applets: https://github.com/adi1090x/rofi
- Add plymouth theme: https://github.com/adi1090x/plymouth-themes
- better font for GTK, maybe SF PRO
- file associations
- ~~fzf broke ctrl-r~~
- copy/paste into terminal in vscode
- ssh-keys are not added to ssh-agent?
- XWayland / electron etc
- trackpad speed
- scroll speed
- bluetooth audio on google meet not resetting
- media keys
- wayland support in apps: https://nixos.wiki/wiki/Wayland

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
