{
  description = "God-mode for NixOS and MacOS";

  inputs = {
    # Common
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-23.05";
    utils.url = "github:numtide/flake-utils";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # secrets = {
    #   url = "git+ssh://git@github.com/donskifarrell/nix-secrets";
    #   inputs.nixpkgs.follows = "nixpkgs";
    #   inputs.agenix.follows = "agenix";
    #   inputs.flake-utils.follows = "utils";
    # };
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
    # Common
    self,
    nixpkgs,
    nixpkgs-stable,
    utils,
    agenix,
    nix-vscode-extensions,
    # secrets,
    home-manager,
    nurl,
    # NIXOS
    nixos-hardware,
    gnomeNixpkgs,
    hyprland,
    # OSX
    darwin,
    nix-homebrew,
    homebrew-core,
    homebrew-cask,
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
          inherit inputs outputs;
          ssh-keys = ssh-keys;
        };
      };
    };

    nixosConfigurations = {
      # Main desktop
      makati = lib.nixosSystem {
        system = "x86_64-linux";
        modules = [./hosts/nixos-desktop.nix];
        specialArgs = {
          inherit inputs outputs;
          ssh-keys = ssh-keys;
        };
      };

      # Qemu VMs
      qemu = lib.nixosSystem {
        system = "x86_64-linux";
        modules = [./hosts/nixos-qemu.nix];
        specialArgs = {
          inherit inputs outputs;
          ssh-keys = ssh-keys;
        };
      };
    };
  };
}
