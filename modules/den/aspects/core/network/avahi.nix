{
  den.aspects.core.network.avahi = {
    nixos =
      { host, ... }:
      # let
      #   interfaces = builtins.attrNames host.networking.interfaces;
      # in
      {
        services.avahi = {
          enable = true;
          # allowInterfaces = interfaces;
          openFirewall = true;
        };
      };
  };
}
