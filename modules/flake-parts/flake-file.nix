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

      devshell.inputs.nixpkgs.follows = "nixpkgs-unstable";
      devshell.url = "github:numtide/devshell";

      disko.inputs.nixpkgs.follows = "nixpkgs-unstable";
      disko.url = "github:nix-community/disko";

      firefox-addons.inputs.nixpkgs.follows = "nixpkgs-unstable";
      firefox-addons.url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";

      flake-file.url = "github:vic/flake-file";

      flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs-unstable";
      flake-parts.url = "github:hercules-ci/flake-parts";

      git-hooks-nix.url = "github:cachix/git-hooks.nix";

      home-manager.inputs.nixpkgs.follows = "nixpkgs-unstable";
      home-manager.url = "github:nix-community/home-manager";

      homebrew-cask.flake = false;
      homebrew-cask.url = "github:homebrew/homebrew-cask";

      homebrew-core.flake = false;
      homebrew-core.url = "github:homebrew/homebrew-core";

      import-tree.url = "github:vic/import-tree";

      microvm.inputs.nixpkgs.follows = "nixpkgs-unstable";
      microvm.url = "github:microvm-nix/microvm.nix";

      nix-ai-tools.inputs.nixpkgs.follows = "nixpkgs-unstable";
      nix-ai-tools.url = "github:numtide/nix-ai-tools";

      nix-darwin.inputs.nixpkgs.follows = "nixpkgs-unstable";
      nix-darwin.url = "github:LnL7/nix-darwin";

      nix-flatpak.url = "github:gmodena/nix-flatpak";

      nix-homebrew.url = "github:zhaofengli/nix-homebrew";

      nix-index-database.inputs.nixpkgs.follows = "nixpkgs-unstable";
      nix-index-database.url = "github:nix-community/nix-index-database";

      nix-rosetta-builder.inputs.nixpkgs.follows = "nixpkgs-unstable";
      nix-rosetta-builder.url = "github:cpick/nix-rosetta-builder";

      nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs-unstable";
      nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

      nixidy.inputs.nixpkgs.follows = "nixpkgs-unstable";
      nixidy.url = "github:arnarg/nixidy";

      nixos-anywhere.inputs.disko.follows = "disko";
      nixos-anywhere.inputs.nixos-stable.follows = "nixpkgs";
      nixos-anywhere.inputs.nixpkgs.follows = "nixpkgs-unstable";
      nixos-anywhere.inputs.treefmt-nix.follows = "treefmt-nix";
      nixos-anywhere.url = "github:numtide/nixos-anywhere";

      nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

      nixos-hardware.url = "github:nixos/nixos-hardware";

      nixpkgs-unstable.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1";
      # Hosts build from `nixpkgs` (Den uses inputs.nixpkgs.legacyPackages).
      # Same FlakeHub weekly as nixpkgs-unstable so host modules+packages and
      # every input's `follows` come from ONE cooldown-protected source; was
      # 26.05-chilled, which made host modules stable-shaped while everything
      # else tracked the weekly. (flake-file can't render a root-level
      # `follows` — url is a non-nullable option — so the URL is duplicated;
      # `nix flake update` keeps both nodes in lockstep.)
      nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1";

      sops-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";
      sops-nix.url = "github:Mic92/sops-nix";

      statix.inputs.flake-parts.follows = "flake-parts";
      statix.inputs.nixpkgs.follows = "nixpkgs-unstable";
      statix.url = "github:oppiliappan/statix";

      steam-config-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";
      steam-config-nix.url = "github:different-name/steam-config-nix";

      stylix.inputs.nixpkgs.follows = "nixpkgs-unstable";
      stylix.url = "github:nix-community/stylix";

      treefmt-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";
      treefmt-nix.url = "github:numtide/treefmt-nix";

      ucodenix.url = "github:e-tho/ucodenix";
    };
  };
}
