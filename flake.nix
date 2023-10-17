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
    secrets = {
      url = "git+ssh://git@github.com/donskifarrell/nix-secrets";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.agenix.follows = "agenix";
      inputs.flake-utils.follows = "utils";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nurl.url = "github:nix-community/nurl";

    # NIXOS
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    agenix,
    secrets,
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

    user = "df";
    # mkNixOSSystem = user: hostname: hardwareModule: extraModules:
    #   nixpkgs.lib.nixosSystem rec {
    #     pkgs = mkPkgs "x86_64-linux";
    #     system = "x86_64-linux";
    #     modules =
    #       [
    #         {_module.args = {inherit inputs;};}
    #         hardwareModule
    #         inputs.agenix.nixosModules.default
    #         home-manager.nixosModules.home-manager
    #         {
    #           home-manager.useGlobalPkgs = true;
    #           home-manager.useUserPackages = true;
    #         }
    #         ./hosts
    #       ]
    #       ++ extraModules;
    #   };
  in {
    nixosConfigurations = {
      # Main desktop
      makati = lib.nixosSystem {
        modules = [./hosts/nixos-desktop];
        specialArgs = {inherit inputs outputs;};
      };

      # Qemu VMs
      qemu = lib.nixosSystem {
        modules = [./hosts/nixos-qemu];
        specialArgs = {inherit inputs outputs;};
      };
    };

    # nixosConfigurations = {
    #   makati = mkNixOSSystem desktop user "makati" [
    #     {
    #       nixpkgs.overlays = [
    #         (self: super: {
    #           gnome = gnomeNixpkgs.legacyPackages.x86_64-linux.gnome;
    #         })
    #       ];
    #     }
    #   ];

    #   # nixos-qemu = mkNixOSSystem user "makati-qemu" [];
    # };

    # darwinConfigurations = let
    #   user = "df";
    # in {
    #   "df-manila-MBP" = darwin.lib.darwinSystem {
    #     system = "aarch64-darwin";
    #     specialArgs = inputs;
    #     modules = [
    #       nix-homebrew.darwinModules.nix-homebrew
    #       {
    #         nix-homebrew = {
    #           enable = true;
    #           user = "${user}";
    #           taps = {
    #             "homebrew/homebrew-core" = homebrew-core;
    #             "homebrew/homebrew-cask" = homebrew-cask;
    #           };
    #           mutableTaps = false;
    #           autoMigrate = true;
    #         };
    #       }
    #       ./manila-osx
    #     ];
    #   };
    # };

    # nixosConfigurations = let
    #   user = "df";
    #   sys = "x86_64-linux";
    #   pkgs = nixpkgs.legacyPackages.${sys};
    #   lib = nixpkgs.lib;

    #   ################################################################################
    #   # BASE SYSTEM CONFIG
    #   ################################################################################
    #   makati-base = {
    #     specialArgs =
    #       inputs
    #       // {
    #         user = "df";
    #         keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKdNislbiV21PqoaREbPATGeCj018IwKufVcgR4Ft9Fl london"];
    #       };
    #     modules = [
    #       home-manager.nixosModules.home-manager
    #       ./makati-nixos
    #       {
    #         home-manager.useGlobalPkgs = true;
    #         home-manager.useUserPackages = true;
    #         home-manager.users.${user} = import ./makati-nixos/home-manager.nix;
    #       }
    #     ];
    #   };
    # in {
    #   makati = nixpkgs.lib.nixosSystem {
    #     system = "x86_64-linux";
    #     specialArgs =
    #       makati-base.specialArgs
    #       // {
    #         hostname = "makati";
    #         vm = false;
    #       };
    #     modules =
    #       makati-base.modules
    #       ++ [
    #         {
    #           nixpkgs.overlays = [
    #             (self: super: {
    #               gnome = gnomeNixpkgs.legacyPackages.x86_64-linux.gnome;
    #             })
    #           ];
    #         }
    #         ./makati-nixos/desk/hardware-configuration.nix
    #       ];
    #   };

    #   nixos-qemu = nixpkgs.lib.nixosSystem {
    #     system = "x86_64-linux";
    #     specialArgs =
    #       makati-base.specialArgs
    #       // {
    #         hostname = "makati-qemu";
    #         vm = true;
    #       };
    #     modules =
    #       makati-base.modules
    #       ++ [
    #         ./makati-nixos/vm/qemu-hardware-configuration.nix
    #         {
    #           # VM specific changes
    #           # Bootloader.
    #           boot.loader.systemd-boot.enable = true;
    #           boot.loader.efi.canTouchEfiVariables = true;

    #           boot.kernelPackages = nixpkgs.lib.mkForce pkgs.linuxPackages_6_1; # To fix an issue with ZFS compatibility
    #           virtualisation.vmVariant = {
    #             virtualisation = {
    #               forwardPorts = [
    #                 {
    #                   from = "host";
    #                   host.port = 2222;
    #                   guest.port = 22;
    #                 }
    #               ];
    #               qemu.options = [
    #                 "-device virtio-vga-gl"
    #                 "-display sdl,gl=on,show-cursor=off"
    #                 "-audio pa,model=hda"
    #                 "-m 16G"
    #               ];
    #             };
    #             services.openssh = {
    #               enable = true;
    #               settings.PasswordAuthentication = true;
    #               settings.PermitRootLogin = nixpkgs.lib.mkForce "yes";
    #             };
    #             # Won't be applied
    #             environment.sessionVariables = {
    #               WLR_NO_HARDWARE_CURSORS = "1";
    #               WLR_RENDERER_ALLOW_SOFTWARE = "1";
    #               # HYPRLAND_LOG_WLR = "1";
    #             };
    #           };
    #         }
    #       ];
    #   };
    # };
  };
}
