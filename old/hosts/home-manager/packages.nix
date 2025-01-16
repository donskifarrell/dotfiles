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

    android-tools
    cargo
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

    hw-probe
    libreoffice-still
    netperf
    opensnitch-ui
    pgadmin4
    sublime4
    telegram-desktop
    ulauncher

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
}
