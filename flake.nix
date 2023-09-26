{
  description = "Donski Configuration for NixOS and MacOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
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
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    hyprland = {
      url = "github:hyprwm/hyprland";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nix-formatter-pack = {
      url = "github:Gerschtli/nix-formatter-pack";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    flake-compat,
    agenix,
    darwin,
    disko,
    nix-homebrew,
    homebrew-core,
    homebrew-cask,
    home-manager,
    hyprland,
    nix-formatter-pack,
    nixos-hardware,
  } @ inputs: let
    user = "df";
    systems = ["x86_64-linux" "aarch64-darwin"];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    devShell = system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = with pkgs;
        mkShell {
          # Enable experimental features without having to specify the argument
          NIX_CONFIG = "experimental-features = nix-command flakes";
          nativeBuildInputs = with pkgs; [fish git age neovim];
          shellHook = with pkgs; ''
            export EDITOR=nvim
          '';
        };
    };
  in {
    devShells = forAllSystems devShell;

    # nix fmt
    formatter = forAllSystems (
      system:
        nix-formatter-pack.lib.mkFormatter {
          pkgs = nixpkgs.legacyPackages.${system};
          config.tools = {
            alejandra.enable = true;
            deadnix.enable = true;
            nixpkgs-fmt.enable = false;
            statix.enable = true;
          };
        }
    );

    darwinConfigurations = let
      user = "df";
    in {
      "df-manila-MBP" = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = inputs;
        modules = [
          nix-homebrew.darwinModules.nix-homebrew
          {
            nix-homebrew = {
              enable = true;
              user = "${user}";
              taps = {
                "homebrew/homebrew-core" = homebrew-core;
                "homebrew/homebrew-cask" = homebrew-cask;
              };
              mutableTaps = false;
              autoMigrate = true;
            };
          }
          ./manila-osx
        ];
      };
    };

    nixosConfigurations = let
      user = "df";
      sys = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${sys};
      lib = nixpkgs.lib;

      ################################################################################
      # BASE SYSTEM CONFIG
      ################################################################################
      makati-base = {
        specialArgs =
          inputs
          // {
            user = "df";
            keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKdNislbiV21PqoaREbPATGeCj018IwKufVcgR4Ft9Fl london"];
          };
        modules = [
          home-manager.nixosModules.home-manager
          ./makati-nixos
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${user} = import ./makati-nixos/home-manager.nix;
          }
        ];
      };
    in {
      makati = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs =
          makati-base.specialArgs
          // {
            hostname = "makati";
            vm = false;
          };
        modules =
          makati-base.modules
          ++ [
            ./makati-nixos/desk/hardware-configuration.nix
            {
              virtualisation = {
                virtualbox = {
                  host.enable = true;
                  host.enableExtensionPack = true;
                  guest.enable = true;
                };
              };
              users.extraGroups.vboxusers.members = ["${user}"];
            }
          ];
      };

      makati-qemu = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs =
          makati-base.specialArgs
          // {
            hostname = "makati-qemu";
            vm = true;
          };
        modules =
          makati-base.modules
          ++ [
            ./makati-nixos/vm/qemu-hardware-configuration.nix
            {
              # VM specific changes
              # Bootloader.
              boot.loader.systemd-boot.enable = true;
              boot.loader.efi.canTouchEfiVariables = true;

              boot.kernelPackages = nixpkgs.lib.mkForce pkgs.linuxPackages_6_1; # To fix an issue with ZFS compatibility
              virtualisation.vmVariant = {
                virtualisation = {
                  forwardPorts = [
                    {
                      from = "host";
                      host.port = 2222;
                      guest.port = 22;
                    }
                  ];
                  qemu.options = [
                    "-device virtio-vga-gl"
                    "-display sdl,gl=on,show-cursor=off"
                    "-audio pa,model=hda"
                    "-m 16G"
                  ];
                };
                services.openssh = {
                  enable = true;
                  settings.PasswordAuthentication = true;
                  settings.PermitRootLogin = nixpkgs.lib.mkForce "yes";
                };
                # Won't be applied
                environment.sessionVariables = {
                  WLR_NO_HARDWARE_CURSORS = "1";
                  WLR_RENDERER_ALLOW_SOFTWARE = "1";
                  # HYPRLAND_LOG_WLR = "1";
                };
              };
            }
          ];
      };

      makati-vb = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs =
          makati-base.specialArgs
          // {
            hostname = "makati-vb";
            vm = true;
          };
        modules =
          makati-base.modules
          ++ [
            ./makati-nixos/vm/virtualbox-hardware-configuration.nix
            {
              # VM specific changes
              # Bootloader.

              boot.loader.systemd-boot.enable = true;
              boot.loader.efi.canTouchEfiVariables = true;

              boot.kernelPackages = nixpkgs.lib.mkForce pkgs.linuxPackages_6_1; # To fix an issue with ZFS compatibility
              virtualisation.vmVariant = {
                virtualisation = {
                  forwardPorts = [
                    {
                      from = "host";
                      host.port = 21212;
                      guest.port = 22;
                    }
                  ];
                };
                services.openssh = {
                  enable = true;
                  settings.PasswordAuthentication = true;
                  settings.PermitRootLogin = nixpkgs.lib.mkForce "yes";
                };
                environment.sessionVariables = {
                  WLR_NO_HARDWARE_CURSORS = "1";
                  WLR_RENDERER_ALLOW_SOFTWARE = "1";
                  HYPRLAND_LOG_WLR = "1";
                };
              };
            }
          ];
      };
    };
  };
}
