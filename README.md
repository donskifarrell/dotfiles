# Aon clan

Using [Clan.lol](https://clan.lol) as an orchestrator.
Heavily borrowed configs from https://github.com/onixcomputer/onix-core and https://github.com/perstarkse/infra

| Hostname            | Users | System         | What is it?         | Used for?                        |
| ------------------- | ----- | -------------- | ------------------- | -------------------------------- |
| abhaile (home)      | df    | x86_64-linux   | Desktop workstation | Primary workstation, misc tasks  |
| iompar (carry)      | df    | aarch64-darwin | M1 Macbook Pro      | Portable workstation, casual use |
| eachtrach (foreign) | mise  | x86_64-linux   | VPS                 | VPN exit node                    |
| short               | mise  | x86_64-linux   | VM                  | local testing                    |
| nas-storage         | tbd   | x86_64-linux   | NAS                 | local backup                     |

## Desired State

I want to have this final state.
Services should be exposed on the clan network using dm-dns: https://clan.lol/docs/unstable/services/official/dm-dns

### Borgbackup

borgbackup docs: https://borgbackup.readthedocs.io/en/stable/index.html
clan.lol docs: https://clan.lol/docs/unstable/services/official/borgbackup
preferred LAN url: borg.aon.clan

| Machine     | Desired State                                              |
| ----------- | ---------------------------------------------------------- |
| abhaile     | send to NAS / use machine as secondary store?              |
| iompar      | not needed                                                 |
| eachtrach   | not needed                                                 |
| short       | send syncthing/paperless/immich backups to NAS on cron job |
| nas-storage | primary BorgBackup store                                   |

### Syncthing

syncthing docs: https://docs.syncthing.net
clan.lol docs: https://clan.lol/docs/unstable/services/official/syncthing
local Clan service: services/syncthing
preferred LAN url: sync-<machine>.aon.clan

| Machine     | ~/sync/obsidian | ~/sync/paperless | ~/sync/photos |
| ----------- | --------------- | ---------------- | ------------- |
| abhaile     | Send & Receive  | Send only        | Send only     |
| iompar      | Send & Receive  | Send only        | Send only     |
| eachtrach   | not needed      | not needed       | not needed    |
| short       | Send & Receive  | Receive only     | Receive only  |
| nas-storage | not needed      | not needed       | not needed    |

#### Folder setup

Machine "short" is the primary store for Syncthing. It pushes backups to Borgbackup daily.

| Folder           | Syncthing Mode |
| ---------------- | -------------- |
| ~/sync/obsidian  | Send & Receive |
| ~/sync/paperless | Send → Receive |
| ~/sync/photos    | Send → Receive |

### Paperless

paperless docs: https://docs.paperless-ngx.com
clan.lol docs: none - standard Nixos packages used.
preferred LAN url: paperless.aon.clan

| Machine     | Desired State                                                             |
| ----------- | ------------------------------------------------------------------------- |
| abhaile     | Connects via web interface. Also has a local backup that can be run       |
| iompar      | Connects via web interface                                                |
| eachtrach   | not needed                                                                |
| short       | Primary store + host for Paperless ng; pushes backups to Borgbackup daily |
| nas-storage | not needed                                                                |

### Immich

Immich docs: https://docs.immich.app/overview/quick-start/
clan.lol docs: none - standard Nixos packages used.
preferred LAN url: photos.aon.clan

| Machine     | Desired State                                                               |
| ----------- | --------------------------------------------------------------------------- |
| abhaile     | Connects via web interface. Also has a local backup that can be run (maybe) |
| iompar      | Connects via web interface                                                  |
| eachtrach   | not needed                                                                  |
| short       | Primary store + host for Immich; pushes backups to Borgbackup daily         |
| nas-storage | not needed                                                                  |

### Tailscale

Each machine is part of the Tailscale network. Certain apps will eventually be exposed outside the network but with strict authentication in place first.

local Clan service: services/tailscale

### Caddy

I will be deploying apps to the "short" machine that will be exposed externally using Caddy.

## Nix

A general good resource is [Awesome Nix](https://github.com/nix-community/awesome-nix) and https://mynixos.com/

- NixOS options: https://search.nixos.org/options?channel=unstable
- HM options: https://home-manager-options.extranix.com/?query=&release=master
- Noogle for Nix options: https://noogle.dev
- NixOS unofficial book: https://nixos-and-flakes.thiscute.world

## Virtual Machines

#### Windows 11

There is this excellent blog: https://blog.redstone.engineer/posts/nixos-windows-guest-graphical-improvement-filesystem-clipboard-sharing-guide/

And this excellent tool: https://schneegans.de/windows/unattend-generator/

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
- For dev VMs, use https://github.com/nix-community/nixos-vscode-server
- Add plymouth theme: https://github.com/adi1090x/plymouth-themes
- Media keys
- BIOS tweak (XMP; V.T on CPU)
- Enforce BT settings - A2DP sink/LDAC for headset

## Misc Links

https://github.com/malob/nixpkgs

https://github.com/mitchellh/nixos-config (Darwin)

https://github.com/chvp/nixos-config (Darwin)

https://github.com/Misterio77/nix-config

https://jeffhandley.com/2021-01-09/family-email-setup
