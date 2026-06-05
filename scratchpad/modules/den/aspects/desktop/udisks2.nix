# Ported from modules/system/udisks2.nix. Removable-media automounting (pairs
# with the udiskie home aspect).
{
  den.aspects.desktop.udisks2.nixos = _: {
    services.udisks2.enable = true;
  };
}
