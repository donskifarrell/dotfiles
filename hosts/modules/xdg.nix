{pkgs, ...}: {
  # XDG Portals
  xdg = {
    autostart.enable = true;

    portal = {
      enable = true;
      # wlr.enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal
        pkgs.xdg-desktop-portal-gtk
      ];
    };
  };
}
