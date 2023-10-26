# My Dots

I've essentially got 3 machines:

| Hostname | Users | System         | What is it?         |
| -------- | ----- | -------------- | ------------------- |
| makati   | df    | x86_64-linux   | Desktop workstation |
| manila   | df    | aarch64-darwin | M1 Macbook Pro      |
| qemu     | df    | x86_64-linux   | VM                  |

These dotfiles try to keep things easy and composable. Everything is driven from the base `flake.nix` using standard tooling.

In `./hosts` you'll find the main configurations for each hostname above. Each config file will have system customisations as needed but the bulk of customisation is simply adding or omitting the relevant import module file.

Similarly for `home-manager`, each hostname config may have the odd customisation, but most of the selection is simply importing the relevant home-manager module.

For user packages, I put everything into `./hosts/home-manager/packages.nix` so it's easier to see what each system has at once.

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

# Get dotfiles from this repo to the path ~/.dotfiles
# I generally don't have keys setup yet, so I pull just the files then switch it later (guessing at the steps:)
cd ~
wget -O .dotfiles.zip https://github.com/donskifarrell/dotfiles/archive/refs/heads/main.zip
unzip .dotfiles.zip

# We need to bootstrap the nix-darwin installer. I use flakes, so we need to use experimental flake commands
# Note: --impure flag is due to some configs like boot timestamp that I need to resolve still.
nix run --extra-experimental-features nix-command --extra-experimental-features flakes nix-darwin -- switch --flake ~/.dotfiles/#manila --impure

# Once that installs, we can use the simpler command in the future (Alias it somewhere)
/run/current-system/sw/bin/darwin-rebuild switch --flake ~/.dotfiles/#manila --impure

```

## NIXOS Fresh Install

The nixos install is more involved, as it's an entire system.

The easiest way is to use the GUI installer from an ISO: https://nixos.org/download.html#nixos-iso

```
TODO
```

TODO: ADD

- Screenshots / recorder
- add swayidle: https://github.com/swaywm/swayidle
- add cron job to switch wallpapers: https://github.com/cronie-crond/cronie
- switch to gtklock: https://github.com/jovanlanik/gtklock/wiki
- swaync widgets: https://github.com/ErikReider/SwayNotificationCenter#available-widgets
  -- audio
  -- player
- ROFI applets: https://github.com/adi1090x/rofi
- decide (and customise) nwg-dock: https://github.com/nwg-piotr/nwg-dock-hyprland/tree/master
- add nixos-search somewhere?
  <!-- - add hardware controls for media -->
  <!-- - vscode extenstions: https://github.com/nix-community/nix-vscode-extensions
    -- catppuccin vscode-icons: https://github.com/catppuccin/vscode-icons
    -- wayou.vscode-todo-highlight -->
- brillo: what is it and should I add?
- plymouth theme: https://github.com/adi1090x/plymouth-themes
  <!-- - theme ROFI catppuccin: https://davatorium.github.io/rofi/current/rofi-theme.5/#examples -->
  <!-- - theme other apps with catppuccin -->
- docker/podman or something
  -- monorepo for all side projects so we can use traefik or similar: https://georgek.github.io/blog/posts/multiple-web-projects-traefik/

TODO: FIX

- create windowrule to open btop in floating window
- fix crashes when monitor turned off: https://github.com/hyprwm/Hyprland/issues/2770
  -- hardware / temp logging
- better font for GTK, maybe SF PRO
- file associations
<!-- - fzf broke ctrl-r -->
- copy/paste into terminal in vscode
- ssh-keys not be auto added?
- XWayland / electron etc
- calendar waybar
- trackpad speed
- scroll speed
- weird blurry cursors
- bluetooth audio on google meet not resetting

useful links:
https://nixos-and-flakes.thiscute.world/nixos-with-flakes/nixos-with-flakes-enabled#adding-custom-cache-mirrors
https://github.com/iamadamdev/bypass-paywalls-chrome

https://unix.stackexchange.com/questions/272660/how-to-split-etc-nixos-configuration-nix-into-separate-modules

https://github.com/schuelermine/xhmm

GTK settings:

```
[Settings]
gtk-theme-name=Adwaita
gtk-icon-theme-name=Adwaita
gtk-font-name=Cantarell 11
gtk-cursor-theme-name=capitaine-cursors
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_ICONS
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-application-prefer-dark-theme=0

```

## TODO

Various common tools

- Look at nix-darwin options: https://daiderd.com/nix-darwin/manual/index.html
- Integrate Aegnix: https://github.com/ryantm/agenix
- Integrate Lorri?: https://github.com/nix-community/lorri
- Create an iso image with base config already installed
- Install tooling:
  - Wireguard, or Tailscale
  - Syncthing
  - Docker, or Podman
  - Direnv
- How do I sync easily:
  - Brave: has a sync chain - way to "nix" it?
  - Vivaldi: has a sync feature - way to "nix" it?
  - Firefox: ?
  - LittleSnitch (OSX) ruleset: Can be copied, or symlinked to Dropbox?
  - fish-shell history
  - .local git configs, and other things

Applications on OSX that still need manual install via App Store:

- Coin Tick - Menu Bar Crypto
- ColorSlurp
- Unsplash Wallpapers
- WireGuard
- Prey (OSX has some trouble installing)

Browser extension that needs to be installed manually:

- Paywall bypass https://github.com/iamadamdev/bypass-paywalls-chrome
  -- unzip to a folder: ~/.bypass-paywalls-chrome so it's out of the way (don't delete folder)

# NixOS & home-manager

Configuration for VMs and OSX. For configuration of Asus ROG Rapture GT-AX6000, look [here](./scripts//asus-gt-ax6000/README.md)

## Useful Repos

https://github.com/malob/nixpkgs

https://github.com/mitchellh/nixos-config

https://github.com/chvp/nixos-config (check out SSH, Secrets)

https://github.com/Misterio77/nix-config

https://gist.github.com/ptrfrncsmrph/2d1646fbb035bd76cf8c691c0d5cf47f#file-flake-nix-L72

> Setup nix, nix-darwin and home-manager from scratch on an M1 Macbook Pro

https://discourse.nixos.org/t/fixing-your-install-after-osx-upgrade/19339

http://ghedam.at/15978/an-introduction-to-nix-shell

> How to use different dev envs

```

```
