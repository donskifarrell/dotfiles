# Ported from modules/system/avahi.nix. mDNS/`.local` discovery.
{
  den.aspects.services.networking.avahi.nixos = _: {
    services.avahi.enable = true;
  };
}
