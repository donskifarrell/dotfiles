# Ported from modules/system/flatpak.nix.
{
  den.aspects.services.flatpak.nixos = _: {
    services.flatpak.enable = true;
  };
}
