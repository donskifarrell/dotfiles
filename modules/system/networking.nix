{
  config.flake.nixosModules.networking =
    { pkgs, ... }:
    {
      config = {
        networking = {
          networkmanager.enable = true;
          useNetworkd = false;
        };
      };
    };
}
