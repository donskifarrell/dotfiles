# storage/udisks2 — removable-media automounting daemon. Pairs with the udiskie
# tray applet (apps/desktop/tray) on a desktop. Ported from
# modules/system/udisks2.nix; relocated from `desktop` into `storage`.
{
  den.aspects.services.udisks2 = {
    nixos =
      { host, ... }:
      {
        services.udisks2.enable = true;
      };

    homeManager =
      { host, ... }:
      {
        services.udiskie.enable = true;
      };
  };
}
