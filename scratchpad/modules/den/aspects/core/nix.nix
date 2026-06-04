# Ported from modules/system/nix-config.nix (server-relevant bits only;
# the nix-vscode-extensions overlay is a desktop concern, left out of core).
{
  den.aspects.core.nix.nixos =
    { pkgs, ... }:
    {
      nixpkgs.config.allowUnfree = true;

      nix = {
        settings = {
          auto-optimise-store = pkgs.stdenv.isLinux;
          max-jobs = "auto";
          experimental-features = [
            "nix-command"
            "flakes"
          ];

          # Nullify the registry for purity.
          flake-registry = builtins.toFile "empty-flake-registry.json" ''{"flakes":[],"version":2}'';

          # @wheel keeps this generic — no hardcoded username in a core aspect.
          trusted-users = [
            "root"
            "@wheel"
          ];
        };

        optimise.automatic = pkgs.stdenv.isLinux;

        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 7d";
        };
      };
    };
}
