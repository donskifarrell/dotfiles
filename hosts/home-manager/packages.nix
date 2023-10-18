{
  pkgs,
  inputs,
}: let

essentials-utils = with pkgs; [
  age
  alejandra
  bash
  bat
  btop
  cht-sh
  coreutils
  curl
  curl
  difftastic
  direnv
  fd
  ffmpeg
  fx
  fzf
  gawk
  git-filter-repo
  iftop
  jq
  killall
  lsof
  neofetch
  netperf
  openssh
  p7zip
  ripgrep
  rlwrap
  rnix-lsp
  shfmt
  tmux
  tree
  unixtools.ifconfig
  unixtools.netstat
  unrar
  wget
];

essentials-dev = with pkgs; [
  (google-cloud-sdk.withExtraComponents [google-cloud-sdk.components.gke-gcloud-auth-plugin])
  android-tools
  # docker
  # docker-compose
  flyctl
  # go
  gopls
  kubectl
  kubectx
  mkcert
  nodejs
  nodePackages_latest.pnpm
];

essentials-gui = with pkgs; [
  _1password
  _1password-gui
  brave
  chromium
  firefox
  gimp
  libreoffice-still
  maestral-gui
  mattermost-desktop
  obsidian
  spotify
  sublime4
  vivaldi
  vlc
  zathura
];

osx = with pkgs; [
  # (nerdfonts.override {fonts = ["JetBrainsMono"];})
  # dejavu_fonts
  # font-awesome
  # hack-font
  # jetbrains-mono
  # meslo-lgs-nf
  # noto-fonts
  # noto-fonts-emoji
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

  # GUI
  opensnitch-ui
];

nixos-gnome = with pkgs; [
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
];

nixos-hyprland = with pkgs; [
  capitaine-cursors
  flameshot
  gtklock
  lm_sensors
  nwg-dock-hyprland
  playerctl
  rofi-wayland
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

in {

packages = essentials-utils
  ++ essentials-dev ++
  ++ essentials-gui ++
  ++ lib.mkIf pkgs.stdenv.hostPlatform.isDarwin osx
  ++ 

}
 