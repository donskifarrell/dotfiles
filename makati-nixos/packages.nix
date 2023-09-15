{pkgs}:
with pkgs; let
  shared-packages = import ../shared/packages.nix {inherit pkgs;};
in
  shared-packages
  ++ [
    # Security and authentication
    _1password-gui

    # App and package management
    appimage-run
    home-manager

    # Media and design tools
    gimp
    vlc
    fontconfig
    font-manager

    # Printers and drivers
    samsung-unified-linux-driver # printer driver

    # Messaging and chat applications

    # Testing and development tools
    direnv
    rnix-lsp # lsp-mode for nix

    # Screenshot and recording tools
    flameshot
    simplescreenrecorder

    # Text and terminal utilities
    tree
    unixtools.ifconfig
    unixtools.netstat

    # File and system utilities
    ledger-live-desktop
    xdg-utils

    # Other utilities

    # PDF viewer
    zathura

    # Music and entertainment
    spotify
  ]
