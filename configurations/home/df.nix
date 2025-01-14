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
    self.homeModules.nh
    self.homeModules.nix
    self.homeModules.nix-index
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
    fish.enable = true;
    fzf.enable = true;
    git.enable = true;
    jq.enable = true;
    neovim.enable = true;

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
      firefox
      vivaldi
      chromium

      # Apps
      element-desktop
      obsidian
      slack

      # Tools
      curl
      p7zip
      playerctl
      unrar
      unzip
      wget

      # Dev
      distrobox
      devbox
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
