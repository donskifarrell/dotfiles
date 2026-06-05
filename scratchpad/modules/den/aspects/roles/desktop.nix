# role-desktop — abhaile's full composition: workstation + a GNOME desktop, AMD
# CPU/GPU, audio, peripherals, virtualization, gaming, and the graphical apps.
# This is the building block for the real desktop host (PLAN phase 3 / 6.6); it
# is intentionally NOT attached to a host in this scratchpad yet (VM-first).
#
# Reconstructed from machines/abhaile/configuration.nix (its system imports +
# its home-manager block).
{ den, ... }:
{
  den.aspects.roles.desktop = {
    includes = with den.aspects; [
      roles.workstation

      # Desktop environment + look
      desktop.gnome
      desktop.fonts
      desktop.keyboard
      desktop.sound
      desktop.printing
      desktop.touchpad
      desktop.flatpak
      desktop.appimage
      desktop.udisks2

      # Hardware
      hardware.cpu.amd
      hardware.gpu.amd
      hardware.bluetooth
      hardware.ledger
      hardware.tweaks

      # Security / discovery / virt
      security.opensnitch
      services.networking.avahi
      virtualization.libvirt

      # Gaming
      apps.gaming.steam
      apps.gaming.alvr

      # Extra dev tooling
      apps.dev.distrobox
      apps.dev.vscode
      apps.dev.claude

      # Graphical apps + trays
      apps.productivity.apps
      apps.desktop.tray
    ];

    # The host-level bits abhaile set inline alongside its imports.
    nixos =
      { pkgs, ... }:
      {
        # xterm-ghostty terminfo for root.
        environment.sessionVariables.TERMINFO_DIRS = "/run/current-system/sw/share/terminfo";

        environment.systemPackages = with pkgs; [
          eza
          ghostty
          ollama-rocm
        ];
      };

    # Home-manager config applied to the desktop's users: flip the package
    # catalog toggles abhaile used, plus its locale/pager session variables.
    homeManager =
      { pkgs, ... }:
      {
      my.packages = {
        # Security / Accounts
        _1password-cli.enable = true;
        _1password-gui.enable = true;
        authenticator.enable = true;

        # Browsers
        brave.enable = true;
        chromium.enable = true;
        firefox.enable = true;
        vivaldi.enable = true;

        # Apps
        maestral-gui.enable = true;
        slack.enable = true;

        # Media
        ffmpeg.enable = true;
        imagemagick.enable = true;
        krita.enable = true;
        vlc.enable = true;

        # Tools
        curl.enable = true;
        dig.enable = true;
        exiftool.enable = true;
        inetutils.enable = true;
        lsof.enable = true;
        p7zip.enable = true;
        unrar.enable = true;
        unzip.enable = true;
        wget.enable = true;
        wl-clipboard.enable = true;

        # Dev
        android-tools.enable = true;
        bore-cli.enable = true;
        nixfmt-rfc-style.enable = true;
        devenv.enable = true;
        glogg.enable = true;
        insomnia.enable = true;
        sqlitebrowser.enable = true;
      };

      home.sessionVariables = {
        LANG = "en_GB.UTF-8";
        LC_CTYPE = "en_GB.UTF-8";
        LC_ALL = "en_GB.UTF-8";
        PAGER = "less -FirSwX";
        MANPAGER = "sh -c 'col -bx | ${pkgs.bat}/bin/bat -l man -p'";
        MANROFFOPT = "-c";
      };
    };
  };
}
