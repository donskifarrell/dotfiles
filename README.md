####

Heavily borrowed from https://github.com/onixcomputer/onix-core and https://github.com/perstarkse/infra

- Tailscale module

## Commands

clan machines install eachtrach \
 --update-hardware-config nixos-facter \
 --phases kexec \
 --target-host root@91.99.168.74

clan templates apply disk single-disk eachtrach --set mainDisk "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_105596894"

clan machines install eachtrach --target-host root@91.99.168.74

---

OLD EACHTRACH FLAKE.NIX:

```
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    clan-core = {
      url = "git+https://git.clan.lol/clan/clan-core";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    import-tree.url = "github:vic/import-tree";

    # home-manager = {
    #   url = "github:nix-community/home-manager";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # NixVirt = {
    #   url = "https://flakehub.com/f/AshleyYakeley/NixVirt/*.tar.gz";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # vars-helper = {
    #   url = "github:perstarkse/clan-vars-helper";
    #   inputs.nixpkgs.follows = "nixpkgs";
    #   inputs.flake-parts.follows = "flake-parts";
    # };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pre-commit-hooks-nix = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      clan-core,
      flake-parts,
      # home-manager,
      # vars-helper,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { config, self, ... }:
      let
        # Import modules directly
        modules = import "${self}/modules/default.nix" { inherit inputs; };
      in
      {
        imports = [
          clan-core.flakeModules.default
          # home-manager.flakeModules.home-manager
          inputs.treefmt-nix.flakeModule

          # (inputs.import-tree ./modules)

          ./parts/devshells.nix
          ./parts/formatter.nix
          ./parts/pre-commit.nix
          ./parts/sops-viz.nix
        ];

        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
        ];

        flake.clan = {
          meta.name = "brasile";
          meta.description = "home cluster";

          inherit modules;

          specialArgs = {
            modules = config.flake;
          };

          inventory = {
            machines = {
              eachtrach = {
                name = "eachtrach";
                tags = [
                  "eachtrach"
                  "server"
                  "tailnet-et"
                ];
                deploy = {
                  targetHost = "root@91.99.168.74";
                };
              };
            };

            instances = {
              # Sets up nix to trust and use the clan cache
              clan-cache = {
                module = {
                  name = "trusted-nix-caches";
                  input = "clan-core";
                };
                roles.default.tags.all = { };
              };

              # Enables secure remote access to the machine over SSH
              sshd-basic = {
                module = {
                  name = "sshd";
                  input = "clan-core";
                };
                roles.server.tags.all = { };
              };

              # An instance of this module will create a user account on the added machines
              # along with a generated password that is constant across machines and user settings.
              user-mise = {
                module = {
                  name = "users";
                  input = "clan-core";
                };
                roles.default.tags = [ "eachtrach" ];
                roles.default.settings = {
                  user = "mise";
                  prompt = false;
                  groups = [
                    "wheel"
                    "networkmanager"
                  ];
                };
              };

              tailnet-et = {
                module = {
                  name = "tailscale";
                  input = "self";
                };
                roles.peer = {
                  tags."tailnet-et" = { };
                  settings = {
                    enableSSH = true;
                    exitNode = true;
                    enableHostAliases = true;
                  };
                };
              };

              # Convenient administration for the Clan App
              admin = {
                roles.default.tags.all = { };
                roles.default.settings = {
                  allowedKeys = {
                    "mise" =
                      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA6h5RafG9hYqgT3nviJO9P9eEUEAHJlIEqFWfoxFOP6";
                  };
                };
              };

              # Will automatically set the emergency access password if your system fails to boot.
              emergency-access = {
                module = {
                  name = "emergency-access";
                  input = "clan-core";
                };

                roles.default.tags.nixos = { };
              };
            };
          };
        };
      }
    );
}
```

---

---

# Dots

| Hostname       | Users | System         | What is it?         |
| -------------- | ----- | -------------- | ------------------- |
| abhaile (home) | df    | x86_64-linux   | Desktop workstation |
| iompar (carry) | df    | aarch64-darwin | M1 Macbook Pro      |
| TODO: qemu     | df    | x86_64-linux   | VM (multiple)       |

These dotfiles try to keep things easy and composable. Everything is driven from the base `flake.nix` using common tooling along with the https://flake.parts/ framework for some autowiring. Some liberal copying from https://github.com/srid/nixos-config and my own previous configs.

A general good resource is https://github.com/nix-community/awesome-nix and https://mynixos.com/

For configuration of Asus ROG Rapture GT-AX6000, look [here](./bin/asus-gt-ax6000/README.md)

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
