{ pkgs, ... }:
{
  essentials-utils = with pkgs; [
    age
    bash
    bat
    bore-cli
    cht-sh
    coreutils
    curl
    difftastic
    drill
    fd
    ffmpeg
    fx
    fzf
    gawk
    iftop
    imagemagick
    jq
    killall
    lsof
    neofetch
    ngrok
    openssh
    p7zip
    pngcrush
    ripgrep
    rlwrap
    tmux
    tree
    trippy
    unixtools.ifconfig
    unixtools.netstat
    unrar
    wget
    zlib
    lm_sensors
    sysstat
  ];

  essentials-dev = with pkgs; [
    (google-cloud-sdk.withExtraComponents [ google-cloud-sdk.components.gke-gcloud-auth-plugin ])
    # docker
    # docker-compose
    alejandra
    android-tools
    cargo
    devbox
    # direnv
    distrobox
    exiftool
    flyctl
    git-filter-repo
    glogg
    gopls
    just
    kubectl
    kubectx
    mkcert
    nil
    nodejs
    nodePackages_latest.pnpm
    nss_latest
    nssTools
    p11-kit
    qrencode
    shfmt
    statix
    # unzip
    upx
    virt-manager
    # virtiofsd # not on OSX
    wireguard-tools

    # linux kernel
    gcc
    gnumake
    flex
    bison

    kdePackages.isoimagewriter
  ];

  essentials-gui = with pkgs; [
    _1password
    _1password-gui
    gimp
    # spotify
  ];

  essentials-x86-gui = with pkgs; [
    brave
    chromium
    firefox
    hw-probe
    libreoffice-still
    maestral-gui
    mattermost-desktop
    netperf
    obsidian
    opensnitch-ui
    pgadmin4
    sublime4
    telegram-desktop
    ulauncher
    # (vivaldi.overrideAttrs (oldAttrs: {
    #   buildPhase =
    #     builtins.replaceStrings
    #     ["for f in libGLESv2.so libqt5_shim.so ; do"]
    #     ["for f in libGLESv2.so libqt5_shim.so libqt6_shim.so ; do"]
    #     oldAttrs.buildPhase;
    # }))
    # .override
    # {
    #   qt5 = qt6;
    #   commandLineArgs = ["--ozone-platform=wayland"];
    #   # The following two are just my preference, feel free to leave them out
    #   proprietaryCodecs = true;
    #   enableWidevine = true;
    # }
    vlc
    wl-clipboard
    wl-clipboard-x11
    zathura
    scrcpy
    skypeforlinux
    steam

    # Quick drop to keep dep in a list for x86
    virtiofsd
    s-tui
    caffeine-ng
    furmark
  ];

  # https://flathub.org
  nixos-flatpak = [
    "com.slack.Slack"
    "com.belmoussaoui.Authenticator"
  ];

  osx-brews = [
    "flyctl" # always ahead of nixpkgs
    "scrcpy" # always ahead of nixpkgs
    "mas"
    "swift-protobuf" # iOS builds bnk
    "grpc-swift" # iOS builds bnk
  ];

  # https://github.com/macos-fuse-t/fuse-t
  osx-casks = [
    "android-studio"
    "appcleaner"
    "balenaetcher"
    "brave-browser"
    "db-browser-for-sqlite"
    "firefox"
    "google-chrome"
    "itsycal"
    "keepingyouawake"
    "libreoffice"
    "little-snitch"
    "maestral"
    "mattermost"
    "obsidian"
    "omnidisksweeper"
    "openmtp"
    "pgadmin4"
    "postman"
    "raycast"
    "rectangle"
    "slack"
    "steam"
    "skype"
    "sublime-text"
    "the-unarchiver"
    "utm"
    "vivaldi"
    "vlc"
  ];

  osx = with pkgs; [
    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
    dejavu_fonts
    font-awesome
    hack-font
    jetbrains-mono
    meslo-lgs-nf
    cocoapods # iOS builds bnk
  ];

  nixos = with pkgs; [
    appimage-run
    catppuccin-gtk
    dconf2nix
    font-manager
    fontconfig
    quickemu
    samsung-unified-linux-driver
    xdg-utils
    aspell
    aspellDicts.en
    hunspell
    capitaine-cursors
    rofi-wayland
    qt6.qtwayland
    qt6.qt5compat
    wirelesstools
  ];

  nixos-gnome = with pkgs; [
    gnome-extension-manager

    gnomeExtensions.dash-to-dock
    # gnomeExtensions.gsconnect
    # gnomeExtensions.mpris-indicator-button
    gnomeExtensions.caffeine
    gnomeExtensions.vitals
    gnomeExtensions.just-perfection
    gnomeExtensions.sound-output-device-chooser
    gnomeExtensions.blur-my-shell
    gnomeExtensions.appindicator
    # gnomeExtensions.gtile
    # gnomeExtensions.gnome-rectangle # https://github.com/acristoffers/gnome-rectangle
    gnomeExtensions.allow-locked-remote-desktop
  ];

  nixos-hyprland = with pkgs; [
    flameshot
    gtklock
    lm_sensors
    nwg-dock-hyprland
    playerctl
    simplescreenrecorder
    swaylock-effects
    swaynotificationcenter
    swww
    wev
    wl-clipboard
    wlogout
    wmctrl
  ];

  qemu = with pkgs; [
  ];
}