# Desktop tray/applet services that ran in abhaile's home-manager: the
# opensnitch GUI (modules/home/opensnitch-ui.nix), udiskie automount tray
# (modules/home/udiskie.nix), and the tailscale systray (modules/home/tailscale.nix).
# Pairs with the system-side security.opensnitch / desktop.udisks2 aspects.
{
  den.aspects.apps.desktop.tray.homeManager = {
    services.opensnitch-ui.enable = true;
    services.udiskie.enable = true;
    services.tailscale-systray.enable = true;
  };
}
