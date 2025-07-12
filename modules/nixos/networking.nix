{
  # Enable networking
  networking.networkmanager.enable = true;

  # Workaround the annoying `Failed to start Network Manager Wait Online` error on switch.
  # https://github.com/NixOS/nixpkgs/issues/180175
  # systemd.services.NetworkManager-wait-online.enable = false;
  networking = {
    useNetworkd = true;
    # useDHCP = false;

    bridges.br0.interfaces = [ "enp9s0" ];
    interfaces.br0.useDHCP = true;
  };
}
