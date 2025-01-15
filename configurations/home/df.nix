{
  flake,
  pkgs,
  lib,
  ...
}:
let
  inherit (flake) inputs;
  inherit (inputs) self;

  # TODO: Move to a top-level config
  homeDir = "/${if pkgs.stdenv.isDarwin then "Users" else "home"}/df";
in
{
  imports = [
    self.homeModules.alacritty
    self.homeModules.direnv
    self.homeModules.fish
    self.homeModules.git
    self.homeModules.nix
    self.homeModules.ssh
    self.homeModules.starship
    self.homeModules.tmux
    self.homeModules.vscode
  ];

  home = {
    stateVersion = "24.11";

    homeDirectory = lib.mkDefault homeDir;
    username = "df";

    sessionVariables = {
      LANG = "en_GB.UTF-8";
      LC_CTYPE = "en_GB.UTF-8";
      LC_ALL = "en_GB.UTF-8";
      PAGER = "less -FirSwX";
      MANPAGER = "sh -c 'col -bx | ${pkgs.bat}/bin/bat -l man -p'";
      MANROFFOPT = "-c";

      EDITOR = "nvim";

      XDG_CACHE_DIR = "${homeDir}/.cache";
      XDG_CACHE_HOME = "${homeDir}/.cache";
      XDG_CONFIG_HOME = "${homeDir}/.config";
      XDG_DATA_HOME = "${homeDir}/.local/share";
    };

    sessionPath = [ "${homeDir}/dev/bin" ];
  };

  # A fix for https://github.com/nix-community/home-manager/issues/2064
  systemd.user.targets.tray = {
    Unit = {
      Description = "Home Manager System Tray";
      Requires = [ "graphical-session-pre.target" ];
    };
  };
  services.udiskie.enable = true;
  services.playerctld.enable = true;

  programs = {
    bat.enable = true;
    btop.enable = true;
    eza.enable = true;
    fd.enable = true;
    fish.enable = true;
    fzf.enable = true;
    git.enable = true;
    jq.enable = true;
    neovim.enable = true;
    ripgrep.enable = true;

    nix-index = {
      enable = true;
      enableFishIntegration = true;
    };

    nh = {
      enable = true;
      # TODO: extract username to a top-level config
      flake = "/home/df/.dotfiles";
    };

    yazi = {
      enable = true;
      enableFishIntegration = true;
    };

    zoxide = {
      enable = true;
      enableFishIntegration = true;
    };
  };

  home.packages =
    with pkgs;
    [
      _1password-cli
      _1password-gui
      authenticator
      maestral-gui

      # Browsers
      brave
      chromium
      firefox
      vivaldi

      # Apps
      element-desktop
      glogg
      krita
      obsidian
      opensnitch-ui
      skypeforlinux
      slack
      vlc

      # Tools
      curl
      exiftool
      ffmpeg
      imagemagick
      lsof
      p7zip
      playerctl
      unrar
      unzip
      wget

      # Dev
      bore-cli
      devbox
      distrobox
      quickemu
      virt-manager

      # Network
      drill
      trippy
    ]
    ++ (
      if pkgs.stdenv.isLinux then
        [
          # Gnome
          # TODO: Remove overlay in default.nix
          gnome-extension-manager
          # gnomeExtensions.allow-locked-remote-desktop
          gnomeExtensions.blur-my-shell
          gnomeExtensions.appindicator
          gnomeExtensions.caffeine
          gnomeExtensions.dash-to-dock
          gnomeExtensions.just-perfection
          gnomeExtensions.pop-shell
          gnomeExtensions.vitals
        ]
      else
        [ ]
    );
}
