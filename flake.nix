{
  description = "Onworld Nix Setup";

  inputs = {
    # Core
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix tooling
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Community flakes
    # impermanence.url = "github:RiscadoA/impermanence";
    # nix-colors.url = "github:misterio77/nix-colors";
  };

  outputs = inputs: let
    # Bring some functions into scope (from builtins and other flakes)
    inherit (builtins) mapAttrs attrValues;
    inherit (inputs.nixpkgs.lib) genAttrs systems;
    forAllSystems = genAttrs systems.flakeExposed;
  in rec {
    # importAttrset = path: mapAttrs (_: import) (import path);

    # TODO: If you want to use packages exported from other flakes, add their overlays here.
    # They will be added to your 'pkgs'
    overlays = {
      default = import ./overlay {inherit inputs;}; # Our own overlay
    };

    # Packages
    # Accessible via 'nix build'
    packages = forAllSystems (system:
      # Propagate nixpkgs' packages, with our overlays applied
        import inputs.nixpkgs {
          inherit system;
          overlays = attrValues overlays;
        });

    # Devshell for bootstrapping
    # Accessible via 'nix develop'
    devShells = forAllSystems (system: {
      default = import ./shell.nix {pkgs = packages.${system};};
    });

    # nixosModules = importAttrset ./modules/nixos;
    # homeManagerModules = importAttrset ./modules/home-manager;

    mkSystem = {
      hostname,
      system ? "x86_64-linux",
      overlays ? {},
      users ? [],
      authorizedKeys ? [],
      persistence ? false,
    }:
      inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs system hostname persistence;};
        modules =
          attrValues (import ./modules/nixos)
          ++ [
            ./hosts/${hostname}/system.nix
            {
              networking.hostName = hostname;
              # Apply overlay and allow unfree packages
              nixpkgs = {
                overlays = attrValues overlays;
                config.allowUnfree = true;
              };
              # Add each input as a registry
              nix.registry =
                inputs.nixpkgs.lib.mapAttrs'
                (n: v: inputs.nixpkgs.lib.nameValuePair n {flake = v;})
                inputs;
            }
            # System wide config for each user
          ]
          ++ inputs.nixpkgs.lib.forEach users (u: {
            pkgs,
            persistence,
            ...
          }: {
            users.users = {
              "${u}" = {
                isNormalUser = true;
                initialPassword = "passwd-change-me-on-login";
                shell = pkgs.fish;
                openssh.authorizedKeys.keys = [] ++ authorizedKeys;
                # TODO: Be sure to add any other groups you need (such as networkmanager, audio, docker, etc)
                extraGroups = ["wheel"];
              };
            };
          });
      };

    # System configurations
    # Accessible via 'nixos-rebuild'
    # NOTE: Add to homeConfigurations below too!
    nixosConfigurations = {
      # OSX Build - just home-manager
      makati = mkSystem {
        inherit overlays;
        hostname = "makati";
        system = "aarch64-linux";
        users = ["df"];
      };

      # NixOS VM - deployed in cloud
      belfast = mkSystem {
        inherit overlays;
        hostname = "belfast";
        system = "aarch64-linux";
        users = ["df"];
      };

      # NixOS VM - usually as QEMU VM
      london = mkSystem {
        inherit overlays;
        hostname = "london";
        system = "aarch64-linux";
        users = ["df"];
        authorizedKeys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKdNislbiV21PqoaREbPATGeCj018IwKufVcgR4Ft9Fl london"];
      };
    };

    mkHome = {
      username,
      hostname,
      system ? "x86_64-linux",
      overlays ? {},
      persistence ? false,
      desktop ? null,
      trusted ? false,
      colorscheme ? "dracula",
    }:
      inputs.home-manager.lib.homeManagerConfiguration {
        inherit username system;
        extraSpecialArgs = {
          inherit
            system
            hostname
            persistence
            desktop
            trusted
            colorscheme
            inputs
            ;
        };

        # TODO: Needed for a bug on hm in OSX. Maybe doesn't matter on Linux?
        # https://github.com/nix-community/home-manager/issues/2622
        stateVersion = "22.05";

        homeDirectory = /home/${username};
        configuration = ./hosts/${hostname}/home.nix;
        extraModules =
          attrValues (import ./modules/home-manager)
          ++ [
            # Base configuration
            {
              nixpkgs = {
                overlays = attrValues overlays;
                config.allowUnfree = true;
              };
              programs = {
                home-manager.enable = true;
                git.enable = true;
              };
            }
          ];
      };

    # Home configurations
    # Accessible via 'home-manager'
    homeConfigurations = {
      "df@makati" = mkHome {
        inherit overlays;
        username = "df";
        hostname = "makati";
        system = "aarch64-darwin";
      };
      "df@belfast" = mkHome {
        inherit overlays;
        username = "df";
        hostname = "belfast";
        system = "aarch64-linux";
      };
      "df@london" = mkHome {
        inherit overlays;
        username = "df";
        hostname = "london";
        system = "aarch64-linux";
      };
    };
  };
}
