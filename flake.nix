{
  description = "God-mode for NixOS and MacOS";

  inputs = {
    # Nikpkgs
    nixpkgs.url = "github:NixOS/nixpkgs/gnome";
    stable-pkgs.url = "github:nixos/nixpkgs/nixos-23.05";

    # Common
    utils.url = "github:numtide/flake-utils";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nurl.url = "github:nix-community/nurl";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

    # NIXOS
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    gnomeNixpkgs.url = "github:NixOS/nixpkgs/gnome";
    hyprland = {
      url = "github:hyprwm/hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # OSX
    darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
  };

  outputs = {
    # Nikpkgs
    nixpkgs,
    stable-pkgs,
    # Common
    agenix,
    nix-vscode-extensions,
    self,
    utils,
    # secrets, # TODO: Add secrets repo
    home-manager,
    nurl,
    # NixOS
    gnomeNixpkgs,
    hyprland,
    nixos-hardware,
    # OSX
    darwin,
    homebrew-cask,
    homebrew-core,
    nix-homebrew,
  } @ inputs: let
    inherit (self) outputs;

    lib = nixpkgs.lib // home-manager.lib;
    systems = ["x86_64-linux" "aarch64-darwin"];
    ssh-keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKdNislbiV21PqoaREbPATGeCj018IwKufVcgR4Ft9Fl london"];

    # TODO: Switch with flake-compat?
    forEachSystem = f: lib.genAttrs systems (system: f pkgsFor.${system});
    pkgsFor = lib.genAttrs systems (system:
      import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          allowBroken = true;
          allowInsecure = false;
          allowUnsupportedSystem = true;

          # Workaround fix: https://github.com/nix-community/home-manager/issues/2942
          allowUnfreePredicate = pkg: true;
        };
      });
  in {
    inherit lib;

    darwinConfigurations = {
      # OSX MBP
      manila = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [./hosts/darwin.nix];
        specialArgs = {
          inherit inputs outputs ssh-keys;
        };
      };
    };

    nixosConfigurations = {
      # Main desktop
      makati = lib.nixosSystem {
        system = "x86_64-linux";
        modules = [./hosts/nixos-desktop.nix];
        specialArgs = {
          inherit inputs outputs ssh-keys;
        };
      };

      # Qemu VMs
      qemu = lib.nixosSystem {
        system = "x86_64-linux";
        modules = [./hosts/nixos-qemu.nix];
        specialArgs = {
          inherit inputs outputs ssh-keys;
        };
      };
    };
  };
}
