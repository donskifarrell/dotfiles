{pkgs}:
with pkgs; [
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
