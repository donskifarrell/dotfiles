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
  zip
  unzip

  # Encryption and security tools
  _1password
  age

  # Cloud-related tools and SDKs
  docker
  docker-compose
  flyctl
  google-cloud-sdk
  go
  gopls

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
]
