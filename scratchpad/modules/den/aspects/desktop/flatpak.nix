# Ported from modules/system/flatpak.nix.
{
  den.aspects.desktop.flatpak.nixos = _: {
    services.flatpak.enable = true;
  };
}
