{
  pkgs,
  lib,
  inputs,
  ...
}: let
  user = "df";
  xdg_configHome = "/home/${user}/.config";
  packages = pkgs.callPackage ./packages.nix {};
  themes = pkgs.callPackage ./custom/rofi-themes.nix {};
  shared-programs = import ../shared/home-manager.nix {inherit pkgs lib;};
  # shared-files = import ../shared/files.nix {inherit config pkgs;};
in {
  home = {
    enableNixpkgsReleaseCheck = false;
    username = "${user}";
    homeDirectory = "/home/${user}";
    packages = pkgs.callPackage ./packages.nix {};
    # file = shared-files // import ./files.nix {inherit user;};
    stateVersion = "23.05";
    sessionVariables = {
      LANG = "en_GB.UTF-8";
      LC_CTYPE = "en_GB.UTF-8";
      LC_ALL = "en_GB.UTF-8";
      EDITOR = "nvim";
      PAGER = "less -FirSwX";
      MANPAGER = "sh -c 'col -bx | ${pkgs.bat}/bin/bat -l man -p'";
      MANROFFOPT = "-c";
    };
  };
  nixpkgs = {
    overlays = [
      (self: super: {
        waybar = super.waybar.overrideAttrs (oldAttrs: {
          mesonFlags = oldAttrs.mesonFlags ++ ["-Dexperimental=true"];
        });
      })
    ];
  };
  fonts.fontconfig.enable = true;

  services = {
    # Screen lock
    # screen-locker = {
    #   enable = true;
    #   inactiveInterval = 10;
    #   lockCmd = "${pkgs.i3lock-fancy-rapid}/bin/i3lock-fancy-rapid 10 15";
    # };

    # Auto mount devices
    udiskie.enable = true;
  };

  programs =
    shared-programs
    // {
      rofi = {
        enable = true;
        package = pkgs.rofi-wayland;
        theme = "${themes.rofi-themes-collection}/themes/spotlight-dark.rasi";
      };
      waybar = {
        enable = true;
        systemd.enable = true;
      };
    };

  wayland.windowManager.hyprland = {
    enable = true;
    enableNvidiaPatches = false;
    systemdIntegration = true;
    xwayland.enable = true;

    settings = {
      "source" = "~/.dotfiles/makati-nixos/custom/hyprland.conf";
    };
  };
}
