{ inputs, ... }:
{
  config.flake.nixosModules.nix-config =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      config = {
        nixpkgs.config.allowUnfree = true;

        nixpkgs.overlays = [
          inputs.nix-vscode-extensions.overlays.default
        ];

        nix = {
          settings = {
            auto-optimise-store = if pkgs.stdenv.isLinux then true else false;

            max-jobs = "auto";
            experimental-features = [
              "nix-command"
              "flakes"
            ];

            # Nullify the registry for purity.
            flake-registry = builtins.toFile "empty-flake-registry.json" ''{"flakes":[],"version":2}'';
            trusted-users = [
              "root"
              config.my.mainUser.name
            ];

            # Allow sandbox to access systemd-resolved for DNS
            # extra-sandbox-paths = [ "/run/systemd/resolve" ];
          };

          optimise.automatic = if pkgs.stdenv.isLinux then true else false;

          gc = {
            automatic = true;
            dates = "weekly";
            options = "--delete-older-than 7d";
          };
        };
      };
    };
}
