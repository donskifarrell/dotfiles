# NixOS & home-manager

Configuration for VMs and OSX

## Usage

- Run `sudo nixos-rebuild switch --flake .#hostname` to apply your system
  configuration.
- Run `home-manager switch --flake .#username@hostname` to apply your home
  configuration.

## Machines

| Hostname | Users  | System                 | What For?                  |
| -------- | ------ | ---------------------- | -------------------------- |
| makati   | donski | aarch64-darwin         | daily driver               |
| belfast  | df     | aarch64-linux (OSX VM) | media and doc backups, vpn |
| london   | df     | ?/vm                   | fun stuff. unstable        |
| dublin   | df     | ?/vm                   | linux workstation          |

Aside from `makati` everything is NixOS based.

```
# Dump of what to install, maybe

df@Belfast - stable VM in the cloud for backups

- syncthing
- paperlessng?
- wireguard
  Takes care of:
  -- Email backup
  -- Docs storage
  -- Photo/Video storage
  -- Misc Files storage

df@London - fun shit?

- k8s cluster in the cloud for all the random sites I want to run?

df@Dublin - Linux workstation

- small base VM image for local or cloud
- stable
  fail2ban
- KDE? Sway? etc

pihole?


TODO:

== FIXES
fzf - preview file on ctrl-T view
forgit/fzf - glo alias, grayed out dates. Also reverse list
nvim - aliases etc

== INSTALLS
Brew
direnv
kubectx https://github.com/ahmetb/kubectx
kubectrl /gcloud https://github.com/kubernetes/kubectl
Vim bufferline https://github.com/akinsho/bufferline.nvim
Vim tree https://github.com/kyazdani42/nvim-tree.lua


### For Review

Secrets, etc https://github.com/jordanisaacs/homeage

https://github.com/myme/dotfiles/tree/1d8e0602e9503c561ca483f6b7708bb1def19486

https://github.com/Gerschtli/nix-config/tree/master

M1 overlay Add access to x86 packages system is running Apple Silicon: https://gist.github.com/ptrfrncsmrph/2d1646fbb035bd76cf8c691c0d5cf47f#file-flake-nix-L72

OSX config: https://discourse.nixos.org/t/simple-workable-config-for-m1-macbook-pro-monterey-12-0-1-with-nix-flakes-nix-darwin-and-home-manager/16834

https://discourse.nixos.org/t/fixing-your-install-after-osx-upgrade/19339

Review settings:

https://github.com/mitchellh/nixos-config/tree/main
(fish funcs)


```

# NixOS Setup

For now, let's assume we're using a VM.
Boot the VM with the NixOS ISO image to get to a live env.
Once at login, set the `nixos` and `root` password. These are throwaway just to enable SSH.

#### REMOTE

```
# Fix root and nixos for SSH
passwd nixos

sudo -i
passwd root

# Get machine ip address
ifconfig
```

Next, copy the script files over.

#### LOCAL

```
# On local
scp -r ./.dotfiles nixos@<machine-ip>:/home/nixos
```

SSH in, and run scripts

#### LOCAL

```
# On local
ssh nixos@<machine-ip>
```

#### REMOTE

```
# On remote machine SSH session
# /boot doesn't always work, so might need manual commands
cd /home/nixos/.dotfiles
sudo sh ./scripts/vm-disk-setup.sh

nix-shell
sudo sh ./scripts/vm-nixos-setup.sh <HOST> <USER>

# If you want, push the changes to a repo. Password token is needed.
git add flake.lock "./hosts/${1}/hardware-configuration.nix"
git commit -am "Committing new hardware-config and flake lock"
git push

# Or copy them back to remote. From LOCAL:
scp -r nixos@<machine-ip>:/home/nixos/.dotfiles/hosts/<HOST>/hardware-configuration.nix <LOCAL_PATH>/.dotfiles/hosts/<HOST>/
scp -r nixos@<machine-ip>:/home/nixos/.dotfiles/hosts/<HOST>/hardware-configuration.nix <LOCAL_PATH>/.dotfiles/hosts/<HOST>/

# Reboot and remove .iso disk
sudo reboot

# After reboot and <USER> login
passwd <USER>
```

#### LOCAL

```
# When SSH'ing into box you will need to clear the fingerprint after install
ssh-keygen -R <machine-ip>
ssh-add ~/.ssh/path/to/key
scp -r ./.dotfiles <USER>@<machine-ip>:/home/<USER>

# Optionally on remote machine, pull files from repo
git clone https://github.com/donskifarrell/dotfiles.git .dotfiles
```

#### REMOTE (on newly installed OS)

```
cd /home/<USER>/.dotfiles
nix-shell
sh ./scripts/vm-first-boot.sh <HOST> <USER>
```

# OSX Setup

Only tested on M1 Macbook Pro.

```
# Make sure we are on the correct system config (rosetta processes will fake the arch as i386/x86_64)
uname -p
uname -m

# Run official installer and follow steps
sh <(curl -L https://nixos.org/nix/install)

# Run setup script
cd ~/.dotfiles
sh scripts/os-hm-setup.sh
source ~/.zprofile # assuming zsh is the shell

# Install home-manager
nix-shell '<home-manager>' -A install

# Install home-manager config
home-manager switch --flake .#username@hostname

```

Applications on OSX that still need manual install:

- Alacritty
- Fonts (Jetbrains Mono)
- Hammerspoon

Some VSCode extensions need to be manually added:

- wayou.vscode-todo-highlight
- vscode-icons-team.vscode-icons
- waderyan.gitblame

# What's next?

## User password and secrets

If you don't want to set your password imperatively, you can also use
`passwordFile` for safely and declaratively setting a password from a file
outside the nix store.

There's also [more advanced options for secret
management](https://nixos.wiki/wiki/Comparison_of_secret_managing_schemes),
including some that can include them (encrypted) into your config repo and/or
nix store, be sure to check them out if you're interested.

## Try opt-in persistance

You might have noticed that there's impurity in your NixOS system, in the form
of configuration files and other cruft your system generates when running. What
if you change them in a whim to get something working and forget about it?
Boom, your system is not fully reproductible anymore.

You can instead fully delete your `/` and `/home` on every boot! Nix is okay
with a empty root on boot (all you need is `/boot` and `/nix`), and will
happily reapply your configurations.

There's two main approaches to this: mount a `tmpfs` (RAM disk) to `/`, or
(using a filesystem such as btrfs or zfs) mount a blank snapshot and reset it
on boot.

For stuff that can't be managed through nix (such as games downloaded from
steam, or logs), use [impermanence](https://github.com/nix-community/impermanence)
for mounting stuff you to keep to a separate partition/volume (such as
`/nix/persist` or `/persist`). This makes everything vanish by default, and you
can keep track of what you specifically asked to be kept.

Here's some awesome blog posts about it:

- [Erase your darlings](https://grahamc.com/blog/erase-your-darlings)
- [Encrypted BTRFS with Opt-In State on
  NixOS](https://mt-caret.github.io/blog/posts/2020-06-29-optin-state.html)
- [NixOS: tmpfs as root](https://elis.nu/blog/2020/05/nixos-tmpfs-as-root/) and
  [tmpfs as home](https://elis.nu/blog/2020/06/nixos-tmpfs-as-home/)

## Adding custom packages

Something you want to use that's not in nixpkgs yet? You can easily build and
iterate on a derivation (package) from this very repository.

Create a folder with the desired name inside `pkgs`, and add a `default.nix`
file containing a derivation. Be sure to also `callPackage` them on
`pkgs/default.nix`.

You'll be able to refer to that package from anywhere on your
home-manager/nixos configurations, build them with `nix build .#package-name`,
or bring them into your shell with `nix shell .#package-name`.

See [the manual](https://nixos.org/manual/nixpkgs/stable/) for some tips on how
to package stuff.

## Adding overlays

Found some outdated package on nixpkgs you need the latest version of? Perhaps
you want to apply a patch to fix a behaviour you don't like? Nix makes it easy
and manageble with overlays!

Use the `overlay/default.nix` file for this.

If you're creating patches, you can keep them on the `overlay` folder as well.

See [the wiki article](https://nixos.wiki/wiki/Overlays) to see how it all
works.

## Adding your own modules

Got some configurations you want to create an abstraction of? Modules are the
answer. These awesome files can expose _options_ and implement _configurations_
based on how the options are set.

Create a file for them on either `modules/nixos` or `modules/home-manager`. Be
sure to also add them to the listing at `modules/nixos/default.nix` or
`modules/home-manager/default.nix`.

See [the wiki article](https://nixos.wiki/wiki/Module) to learn more about
them.

## Nix Starter Config (Full version)

This repo was based heavily off this starter: https://github.com/Misterio77/nix-starter-config
