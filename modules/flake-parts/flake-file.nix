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

      # nix-ai-tools deliberately does NOT follow nixpkgs-unstable, and is
      # declared in modules/den/aspects/apps/ai-tools.nix rather than here:
      # numtide build+push claude-code/pi to cache.numtide.com against their
      # own locked nixpkgs, so overriding the follows changes derivation
      # hashes and turns both into local rebuilds. (A stale `follows` line
      # lived here until 2026-08-22 and made `nix flake check`'s
      # check-flake-file fail against the committed flake.nix, which has never
      # carried it.)

      # nix-darwin/homebrew/rosetta-builder: unused today, kept for the
      # planned macbook host (2026-07-14).
      nix-darwin.inputs.nixpkgs.follows = "nixpkgs-unstable";
      nix-darwin.url = "github:LnL7/nix-darwin";

      nix-homebrew.url = "github:zhaofengli/nix-homebrew";

      nix-index-database.inputs.nixpkgs.follows = "nixpkgs-unstable";
      nix-index-database.url = "github:nix-community/nix-index-database";

      nix-rosetta-builder.inputs.nixpkgs.follows = "nixpkgs-unstable";
      nix-rosetta-builder.url = "github:cpick/nix-rosetta-builder";

      nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs-unstable";
      nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

      # nixos-anywhere: provisions fresh hosts (kexec takes over a stock
      # Ubuntu VPS image — the eachtrach path, TODO item 2).
      nixos-anywhere.inputs.disko.follows = "disko";
      nixos-anywhere.inputs.nixos-stable.follows = "nixpkgs";
      nixos-anywhere.inputs.nixpkgs.follows = "nixpkgs-unstable";
      nixos-anywhere.inputs.treefmt-nix.follows = "treefmt-nix";
      nixos-anywhere.url = "github:numtide/nixos-anywhere";

      nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

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

      treefmt-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";
      treefmt-nix.url = "github:numtide/treefmt-nix";

      # Pruned 2026-07-14 (declared but referenced nowhere): firefox-addons,
      # nix-flatpak, nixidy, nixos-hardware, steam-config-nix, stylix,
      # ucodenix. Re-add via flake-file when something actually consumes them
      # (steam-config-nix when gaming gets wired back onto abhaile).
    };
  };
}
