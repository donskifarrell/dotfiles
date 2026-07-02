# Auto-wire pkgs/by-name/<name>/package.nix into `packages.<name>` (so
# `nix build .#<name>` works and the devshell can reference
# config.packages.<name>). nixpkgs-style by-name layout without the shard
# prefix; each package.nix is callPackage'd and declares its own dependencies.
{
  perSystem =
    { pkgs, lib, ... }:
    {
      packages =
        removeAttrs
          (lib.packagesFromDirectoryRecursive {
            inherit (pkgs) callPackage;
            directory = ../../pkgs/by-name;
          })
          [
            # Incomplete port from sini-nix: needs pkgs/by-name/nix-flake-provision-keys
            # and an agenix-rekey -> sops-nix rework before it can build.
            "nix-flake-install"
          ];
    };
}
