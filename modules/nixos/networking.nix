{
  # Enable networking
  networking.networkmanager.enable = true;

  # Workaround the annoying `Failed to start Network Manager Wait Online` error on switch.
  # https://github.com/NixOS/nixpkgs/issues/180175
  # systemd.services.NetworkManager-wait-online.enable = false;
  networking = {
    useNetworkd = false;
    # useDHCP = false;

    bridges.br0.interfaces = [ "enp9s0" ];
    interfaces.br0.useDHCP = true;
    firewall = {
      trustedInterfaces = [
        "wlp5s0"
        "virbr0"
        "enp9s0"
        "tailscale0"
      ];
      allowedUDPPorts = [ 41641 ];
      checkReversePath = "loose";
    };

    # MagicDNS for Tailscale
    nameservers = [
      "100.100.100.100"
      "8.8.8.8"
      "1.1.1.1"
    ];
    search = [ "tail8f3a60.ts.net" ];
  };

  services.tailscale.enable = true;
}
