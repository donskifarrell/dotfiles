{
  lib,
  user,
  pkgs,
  ...
}:
{
  nix = {
    settings = {
      auto-optimise-store = lib.mkDefault true;
      warn-dirty = false;
    };

    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
    };
  };
}
