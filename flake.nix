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

    NixVirt = {
      url = "https://flakehub.com/f/AshleyYakeley/NixVirt/*.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Private repo
    mono = {
      # url = "git+ssh://git@github.com/donskifarrell/mono.git";
      url = "path:/home/df/dev/mono";
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
              # For new machines using NixOS iso:
              #
              # 1. Set on root first before ssh can work `sudo passwd`
              # 2. clan machines init-hardware-config <machine> --target-host root@192.168.122.217
              # 3. clan templates apply disk single-disk short --set mainDisk ""
              # 4. clan machines install <machine> --target-host root@192.168.122.217
              #

              # eachtrach = {
              #   deploy.targetHost = "root@91.99.168.74";
              #   tags = [ "server" "tailscale-exit"];
              # };

              short = {
                deploy.targetHost = "root@192.168.122.218";
                tags = [
                  "vm"
                  "tailscale"
                ];
              };

              abhaile = {
                deploy.targetHost = "root@192.168.178.26";
                tags = [
                  "abhaile"
                  "tailscale"
                ];
              };
            };

            instances = {
              internet = {
                # roles.default.machines.eachtrach = {
                #   settings.host = "eachtrach.lan";
                # };
                roles.default.machines.short = {
                  settings.host = "short.lan";
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

                roles.default.tags.vm = { };

                roles.default.settings = {
                  user = "mise";
                  prompt = true;
                  groups = [
                    "networkmanager"
                    "wheel"
                  ];
                };
              };

              user-df = {
                module = {
                  name = "users";
                  input = "clan-core";
                };
                roles.default.machines.abhaile = { };
                roles.default.settings = {
                  user = "df";
                  prompt = true;
                  groups = [
                    "networkmanager"
                    "wheel"
                  ];
                };
              };

              aon-tailnet = {
                module = {
                  name = "tailscale";
                  input = "self";
                };
                roles.peer = {
                  tags.tailscale = { };
                  settings = {
                    enableSSH = true;
                    exitNode = false; # currently breaks iptables on desktop install
                    enableHostAliases = true;
                  };
                };
              };

              aon-tailnet-exit = {
                module = {
                  name = "tailscale";
                  input = "self";
                };
                roles.peer = {
                  machines.eachtrach = { };
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

                roles.default.tags.all = { };
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
                nixfmt.enable = true;
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

            # pre-commit = {
            #   check.enable = true;

            #   settings = {
            #     hooks = {
            #       # Core formatting using existing treefmt setup
            #       treefmt = {
            #         enable = true;
            #       };

            #       # Nix-specific linting
            #       statix.enable = true;
            #       deadnix.enable = true;
            #     };

            #     # Exclude files that shouldn't be checked
            #     excludes = [
            #       "^vars/" # SOPS-managed secrets
            #       "^sops/" # SOPS configuration
            #       "\\.age$" # Age-encrypted files
            #       "\\.png$|\\.jpg$|\\.svg$" # Images
            #       "flake\\.lock$" # Generated file
            #     ];
            #   };
            # };

            # Flake checks: treefmt (module-provided) + per-host builds
            checks = buildChecks;
          };
      }
    );
}
