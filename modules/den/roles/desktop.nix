# role-desktop — abhaile's full composition: workstation + a GNOME desktop, AMD
# CPU/GPU, audio, peripherals, virtualization, gaming, and the graphical apps.
# This is the building block for the real desktop host (PLAN phase 3 / 6.6); it
# is intentionally NOT attached to a host in this scratchpad yet (VM-first).
#
# Reconstructed from machines/abhaile/configuration.nix (its system imports +
# its home-manager block).
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
