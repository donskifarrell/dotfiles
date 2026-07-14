# role-desktop — the graphical-desktop concerns on top of role-workstation:
# GNOME + fonts/xdg, sound, flatpak, opensnitch, udisks2, appimage. Included
# by abhaile (and df's user aspect for its homeManager side). Hardware (GPU/
# CPU) stays in the host's own includes; gaming isn't wired anywhere yet
# (deliberate — TODO item 12).
{ den, pkgs, ... }:
{
  den.aspects.roles.desktop = {
    includes = with den.aspects; [
      core.desktop.fonts
      core.desktop.xdg

      services.flatpak
      services.gnome
      services.opensnitch
      services.sound
      services.udisks2

      apps.appimage
    ];

    home.sessionVariables = {
      PAGER = "less -FirSwX";
      MANPAGER = "sh -c 'col -bx | ${pkgs.bat}/bin/bat -l man -p'";
      MANROFFOPT = "-c";
    };
  };
}
