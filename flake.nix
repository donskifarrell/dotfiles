{
  description = "NixOS configuration — Den + sops-nix + deploy-rs (dendritic, flake-parts)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

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

    claude-code.url = "github:sadjow/claude-code-nix";

    den.url = "github:denful/den";

    # Den's facter/disko aspects expect these as root inputs (Den's own flake is
    # input-less). Den emits nixosConfigurations.<host> and imports each machine's
    # disko layout + facter hardware report directly.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-facter-modules.url = "github:nix-community/nixos-facter-modules";

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
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
      flake-parts,
      home-manager,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { ... }:
      {
        imports = [
          home-manager.flakeModules.home-manager
          inputs.treefmt-nix.flakeModule

          # Auto-import every feature module under ./modules (dendritic pattern).
          # Den (modules/den/**) emits nixosConfigurations.<host> from hosts/<host>.nix.
          (inputs.import-tree ./modules)

          (
            { inputs, ... }:
            {
              flake.nixosModules = inputs.mono.nixosModules;
            }
          )
        ];

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
                config.treefmt.build.wrapper
                pkgs.statix
                pkgs.deadnix

                # Deploy + secrets tooling.
                pkgs.deploy-rs
                pkgs.nixos-anywhere
                pkgs.sops
                pkgs.ssh-to-age
                pkgs.age
              ];
            };

            # Flake checks: treefmt (module-provided) + per-host toplevel builds.
            checks = buildChecks;
          };
      }
    );
}
