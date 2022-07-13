# NixOS & home-manager

Configuration for VMs and OSX

## Usage

- Run `sudo nixos-rebuild switch --flake .#hostname` to apply your system
  configuration.
- Run `home-manager switch --flake .#username@hostname` to apply your home
  configuration.

## TODO

- Stop scripts if args are bad
- shell-formatter in vscode is broken on OSX
- Integrate lorri https://github.com/nix-community/lorri

## Machines

| Hostname | Users  | System                 | What For?                  |
| -------- | ------ | ---------------------- | -------------------------- |
| makati   | donski | aarch64-darwin         | daily driver               |
| belfast  | df     | ?/cloud vm             | media and doc backups, vpn |
| london   | df     | aarch64-linux (OSX VM) | fun stuff. unstable        |
| dublin   | df     | ?/vm                   | linux workstation          |

All machines use [home-manager](https://github.com/nix-community/home-manager), and aside from `makati`, everything is [NixOS](https://nixos.org/) based.

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

```

# NixOS Setup

For now, let's assume we're using a VM.
Boot the VM with the NixOS ISO image to get to a live env.

Useful blog post: https://calcagno.blog/m1dev/

## ISO

Review the UEFI installation page: https://nixos.wiki/wiki/NixOS_on_ARM/UEFI

> In short, unstable ISO images can be found here: https://hydra.nixos.org/job/nixos/trunk-combined/nixos.iso_minimal_new_kernel.aarch64-linux

Once at login, set the `nixos` and `root` password. These are throwaway just to enable SSH.

#### REMOTE

```
# Fix root and nixos for SSH
passwd nixos

sudo -i
passwd root

# Get machine ip address
ifconfig

# create /home/nixos/.dotfiles
mkdir -p .dotfiles
```

Next, copy the script files over.

#### LOCAL

```
# On local

# When SSH'ing into box you will need to clear the fingerprint after install
ssh-keygen -R <machine-ip>

GLOBIGNORE='.git' scp -o IdentitiesOnly=yes -r ~/.dotfiles/* nixos@<machine-ip>:/home/nixos/.dotfiles
```

SSH in, and run scripts

#### LOCAL

```
# On local
ssh -o IdentitiesOnly=yes nixos@<machine-ip>
```

#### REMOTE

```
# On remote machine SSH session
# /boot doesn't always work, so might need manual commands
cd /home/nixos/.dotfiles
sudo sh ./scripts/vm-disk-setup.sh

nix-shell
sudo sh ./scripts/vm-nixos-setup.sh -h <TARGET_HOSTNAME>

# If you want, push the changes to a repo. Password token is needed.
git add "./hosts/<TARGET_HOSTNAME>/hardware-configuration.nix"
# If first time running the flake:
# git add flake.lock
git commit -am "Committing new hardware-config"
git push

# Or copy them back to remote. From LOCAL:
scp -r nixos@<machine-ip>:/home/nixos/.dotfiles/hosts/<TARGET_HOSTNAME>/hardware-configuration.nix <LOCAL_PATH>/.dotfiles/hosts/<TARGET_HOSTNAME>/
# scp -r nixos@<machine-ip>:/home/nixos/.dotfiles/flake.lock <LOCAL_PATH>/.dotfiles/

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
sh ./scripts/vm-first-boot.sh -h <TARGET_HOSTNAME> -u <USER>
```

# OSX Setup

Only tested on M1 Macbook Pro.

## Backup

Apps that I should manually backup:

```
- Brave/Vivaldi/Firefox
-- just zip their profile folders
- Check brewfile is updated
- Little Snitch ruleset
- fish shell history
- .local folder (mainly git configs)
- .ssh folder
- .hammerspoon if anything changes
- .kube and .gcloud
```

## Install

Run through these steps for a mostly automated installation

```
# Install the XCode developer tools first (running `git --version` triggers it)
xcode-select --install

# Make sure we are on the correct system config (rosetta processes will fake the arch as i386/x86_64)
uname -p
uname -m

# Run official installer and follow steps
sh <(curl -L https://nixos.org/nix/install)

# Run setup script
cd ~/.dotfiles
sh scripts/osx-hm-setup.sh

# Install home-manager
nix-shell '<home-manager>' -A install

# Install home-manager config
home-manager switch --flake .#username@hostname

# Copy over local configs. In fish shell
restore_local_config ~/.dotfiles/secrets/<age file>

# Copy over SSH keys. In fish shell
restore_ssh ~/.dotfiles/secrets/<age file>

# Setup
sh scripts/osx-set-defaults.sh
```

Applications on OSX that still need manual install via App Store:

- Coin Tick - Menu Bar Crypto
- ColorSlurp
- Unsplash Wallpapers
- WireGuard

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
Boom, your system is not fully reproducible anymore.

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
and manageable with overlays!

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
