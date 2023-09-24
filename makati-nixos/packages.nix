{pkgs}:
with pkgs; let
  shared-packages = import ../shared/packages.nix {inherit pkgs;};
  themes = pkgs.callPackage ./custom/rofi-themes.nix {};
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

    opensnitch-ui
    brave
    chromium
    vivaldi
    firefox
    maestral-gui
    _1password-gui
    mattermost-desktop
    obsidian
    sublime4
    vscode
    hunspell
    libreoffice-still

    quickemu
    dconf2nix
    rofi-wayland
    nwg-dock-hyprland
    swaylock
    swaynotificationcenter

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })
    (google-cloud-sdk.withExtraComponents [google-cloud-sdk.components.gke-gcloud-auth-plugin])
    (nerdfonts.override {fonts = ["JetBrainsMono"];})

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')

    themes.rofi-themes-collection

    gnome-extension-manager
    gnomeExtensions.dash-to-dock
    gnomeExtensions.gsconnect
    gnomeExtensions.mpris-indicator-button
    gnomeExtensions.caffeine
    gnomeExtensions.vitals
    gnomeExtensions.just-perfection
    gnomeExtensions.sound-output-device-chooser
    gnomeExtensions.blur-my-shell
    gnomeExtensions.appindicator
    gnomeExtensions.gtile
    gnomeExtensions.allow-locked-remote-desktop
  ]
