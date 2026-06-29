{ inputs, ... }:
{
  imports = [
    (inputs.flake-file.flakeModules.dendritic or { })
    (inputs.den.flakeModules.dendritic or { })
  ];

  flake-file = {
    description = ''
      Aonix
    '';

    prune-lock.enable = true;

    nixConfig = {
      abort-on-warn = false;
      accept-flake-config = true;
      allow-import-from-derivation = true;
      auto-optimise-store = true;

      extra-substituters = [
        "https://nix-community.cachix.org"
        "https://install.determinate.systems"
      ];

      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      ];

      lazy-trees = true;
      submodules = true;
      use-xdg-base-directories = true;
    };

    inputs = {
      # Private repo
      # mono = {
      #   # url = "git+ssh://git@github.com/donskifarrell/mono.git";
      #   url = "path:/home/df/dev/mono";
      #   inputs.nixpkgs.follows = "nixpkgs";
      #   inputs.flake-parts.follows = "flake-parts";
      # };

      den.url = "github:denful/den";

      devshell = {
        url = "github:numtide/devshell";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      disko = {
        url = "github:nix-community/disko";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      firefox-addons = {
        url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      flake-file.url = "github:vic/flake-file";

      flake-parts = {
        url = "github:hercules-ci/flake-parts";
        inputs.nixpkgs-lib.follows = "nixpkgs-unstable";
      };

      git-hooks-nix.url = "github:cachix/git-hooks.nix";

      home-manager = {
        url = "github:nix-community/home-manager";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      homebrew-cask = {
        url = "github:homebrew/homebrew-cask";
        flake = false;
      };

      homebrew-core = {
        url = "github:homebrew/homebrew-core";
        flake = false;
      };

      import-tree.url = "github:vic/import-tree";

      microvm = {
        url = "github:microvm-nix/microvm.nix";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      nix-ai-tools.url = "github:numtide/nix-ai-tools";

      nix-darwin = {
        url = "github:LnL7/nix-darwin";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      nix-flatpak.url = "github:gmodena/nix-flatpak";

      nix-homebrew.url = "github:zhaofengli/nix-homebrew";

      nix-index-database = {
        url = "github:nix-community/nix-index-database";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      nix-rosetta-builder = {
        url = "github:cpick/nix-rosetta-builder";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      nix-vscode-extensions = {
        url = "github:nix-community/nix-vscode-extensions";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      nixidy = {
        url = "github:arnarg/nixidy";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      nixos-anywhere = {
        url = "github:numtide/nixos-anywhere";
        inputs = {
          disko.follows = "disko";
          flake-parts.follows = "flake-parts";
          nixos-stable.follows = "nixpkgs";
          nixpkgs.follows = "nixpkgs-unstable";
          treefmt-nix.follows = "treefmt-nix";
        };
      };

      nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

      nixos-hardware.url = "github:nixos/nixos-hardware";

      nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
      nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

      statix = {
        url = "github:oppiliappan/statix";
        inputs = {
          flake-parts.follows = "flake-parts";
          nixpkgs.follows = "nixpkgs-unstable";
        };
      };

      steam-config-nix = {
        url = "github:different-name/steam-config-nix";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      stylix = {
        url = "github:nix-community/stylix";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      sops-nix = {
        url = "github:Mic92/sops-nix";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      treefmt-nix = {
        url = "github:numtide/treefmt-nix";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      ucodenix = {
        url = "github:e-tho/ucodenix";
      };
    };
  };
}
