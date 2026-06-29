# Ported from modules/system/nh.nix. nh owns garbage collection, so the
# `nix.gc` schedule in core.nix is force-disabled wherever this aspect is
# included (matching the legacy module's `nix.gc.automatic = mkForce false`).
{
  den.aspects.core.nix.nh.nixos =
    { lib, ... }:
    {
      programs.nh = {
        enable = true;
        clean.enable = true;
        clean.extraArgs = "--keep-since 1m --keep 7";

        flake = "/home/df/.dotfiles";
      };

      nix.gc.automatic = lib.mkForce false;
    };
}

# { den, lib, ... }:
# {
#   perSystem = { pkgs, ... }: {
#     packages = den.lib.nh.denPackages { fromFlake = true; } pkgs;
#   };
# }
