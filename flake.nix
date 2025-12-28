{
  description = "Clan configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    clan-core = {
      url = "git+https://git.clan.lol/clan/clan-core";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    import-tree.url = "github:vic/import-tree";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mono = {
      url = "git+ssh://git@github.com/donskifarrell/mono.git";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
  };

  outputs =
    inputs@{
      clan-core,
      flake-parts,
      home-manager,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { config, ... }:
      {
        imports = [
          home-manager.flakeModules.home-manager
          inputs.clan-core.flakeModules.default
          inputs.treefmt-nix.flakeModule

          (inputs.import-tree ./modules)

          (
            { inputs, ... }:
            {
              flake.nixosModules = inputs.mono.nixosModules;
            }
          )
        ];

        flake.clan = {
          meta.name = "aon";
          meta.domain = "aon.df";

          modules."tailscale" = import ./services/tailscale/default.nix;

          specialArgs = {
            modules = config.flake;
          };

          inventory = {
            machines = {
              # eachtrach = {
              #   deploy.targetHost = "root@91.99.168.74";
              #   tags = [ "server" ];
              # };
              hellovm = {
                deploy.targetHost = "root@192.168.122.77";
                tags = [ "vm" ];
              };
            };

            instances = {
              internet = {
                # roles.default.machines.eachtrach = {
                #   settings.host = "eachtrach.lan";
                # };
                roles.default.machines.hellovm = {
                  settings.host = "hellovm.lan";
                };
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
                roles.default.tags.all = { };
                roles.default.settings = {
                  user = "mise";
                  prompt = false;
                  groups = [
                    "networkmanager"
                    "wheel"
                  ];
                };
              };

              tailnet = {
                module = {
                  name = "tailscale";
                  input = "self";
                };
                roles.peer = {
                  tags.all = { };
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
                    "root" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA6h5RafG9hYqgT3nviJO9P9eEUEAHJlIEqFWfoxFOP6";
                  };
                };
              };

              # Sets up nix to trust and use the clan cache
              clan-cache = {
                module = {
                  name = "trusted-nix-caches";
                  input = "clan-core";
                };
                roles.default.tags.all = { };
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

        systems = [
          "x86_64-linux"
          "aarch64-darwin"
        ];

        perSystem =
          {
            pkgs,
            system,
            config,
            ...
          }:
          let
            inherit (pkgs) lib;
            nixosConfigs = config.flake.nixosConfigurations or { };
            buildChecks = lib.mapAttrs (_: cfg: cfg.config.system.build.toplevel) (
              lib.filterAttrs (_: cfg: (cfg.pkgs.stdenv.hostPlatform.system or null) == system) nixosConfigs
            );
          in
          {
            treefmt = {
              projectRootFile = "flake.nix";
              programs = {
                alejandra.enable = true;
                statix.enable = true;
                deadnix.enable = true;
              };
            };

            formatter = config.treefmt.build.wrapper;

            devShells.default = pkgs.mkShell {
              packages = [
                clan-core.packages.${system}.clan-cli
                config.treefmt.build.wrapper
                pkgs.statix
                pkgs.deadnix
              ];
            };

            # Flake checks: treefmt (module-provided) + per-host builds
            checks = buildChecks;
          };
      }
    );
}
