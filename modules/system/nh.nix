{
  config.flake.nixosModules.nh =
    { lib, ... }:
    {
      config = {
        programs.nh = {
          enable = true;
          clean.enable = true;
          clean.extraArgs = "--keep-since 1m --keep 7";
        };

        nix.gc.automatic = lib.mkForce false;
      };
    };
}
