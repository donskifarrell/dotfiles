{
  flake,
  pkgs,
  lib,
  ...
}:

let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  nixpkgs = {
    config = {
      allowBroken = true;
      allowUnsupportedSystem = true;
      allowUnfree = true;

      permittedInsecurePackages = [
      ];
    };

    overlays = lib.attrValues self.overlays;

    # TODO: Fix overlays
    # overlays =
    #   # Apply each overlay found in the /overlays directory
    #   let
    #     path = "../../overlays/${if pkgs.stdenv.isDarwin then "darwin" else "nixos"}";
    #   in
    #   with builtins;
    #   map (n: import (path + ("/" + n))) (
    #     filter (n: match ".*\\.nix" n != null || pathExists (path + ("/" + n + "/default.nix"))) (
    #       attrNames (readDir path)
    #     )
    #   );
  };

  nix = {
    # Choose from https://search.nixos.org/packages?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=nix
    # package = pkgs.nixVersions.latest;

    nixPath = [ "nixpkgs=${flake.inputs.nixpkgs}" ]; # Enables use of `nix-shell -p ...` etc
    registry.nixpkgs.flake = flake.inputs.nixpkgs; # Make `nix shell` etc use pinned nixpkgs

    settings = {
      max-jobs = "auto";
      experimental-features = "nix-command flakes";
      # Nullify the registry for purity.
      flake-registry = builtins.toFile "empty-flake-registry.json" ''{"flakes":[],"version":2}'';
      trusted-users = [
        "root"
        (if pkgs.stdenv.isDarwin then flake.config.me.username else "@wheel")
      ];
    };
  };
}
