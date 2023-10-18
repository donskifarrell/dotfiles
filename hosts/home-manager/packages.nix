{
  pkgs,
  inputs,
}:
with pkgs; let
  shared-packages = import ../shared/packages.nix {inherit pkgs;};
in
  # COMMONS
  [
    # General packages for development and system management
    alacritty
    aspell
    aspellDicts.en
    bat
    btop
    coreutils
    difftastic
    killall
    neofetch
    openssh
    wget
    archiver
    p7zip

    git-filter-repo

    # Encryption and security tools
    _1password
    age

    # Cloud-related tools and SDKs
    docker
    docker-compose
    flyctl
    go
    gopls
    kubectl
    kubectx

    # Media-related packages
    dejavu_fonts
    ffmpeg
    fd
    font-awesome
    glow
    hack-font
    noto-fonts
    noto-fonts-emoji
    meslo-lgs-nf

    # Node.js development tools
    fzf
    nodejs
    nodePackages_latest.pnpm

    # Source code management, Git, GitHub tools

    # Text and terminal utilities
    htop
    hunspell
    iftop
    jetbrains-mono
    jq
    ripgrep
    tree
    tmux
    unrar
    bash
    gawk
    fx

    # unixtools.netstat # Won't build on OSX. Might need it for linux and tmux bar

    curl
    alejandra
    cht-sh
    rlwrap
    mkcert
    shfmt
    netperf

    wmctrl
    lsof
    android-tools
  ]
  ++ [
    # Security and authentication

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
    hyprpicker
    wl-clipboard
    wlogout
    capitaine-cursors
    swww

    quickemu
    dconf2nix
    rofi-wayland
    nwg-dock-hyprland
    gtklock
    swaylock-effects
    swaynotificationcenter
    catppuccin-gtk
    lm_sensors
    playerctl

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
