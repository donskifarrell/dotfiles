{
  den.aspects.core.network.manager = {
    nixos =
      {
        pkgs,
        ...
      }:
      {
        networking.networkmanager = {
          enable = true;
        };

        networking.useNetworkd = false;

        systemd.services.NetworkManager-wait-online.enable = false;
      };

    cache.directories = [
      "/etc/NetworkManager/system-connections"
      "/var/lib/NetworkManager"
    ];
  };
}
