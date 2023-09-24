{
  config,
  pkgs,
  lib,
  ...
}: let
  user = "df";
  xdg_configHome = "/home/${user}/.config";
  packages = pkgs.callPackage ./packages.nix {};
  themes = pkgs.callPackage ./custom/rofi-themes.nix {};
  shared-programs = import ../shared/home-manager.nix {inherit config pkgs lib;};
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

    extraConfig = ''
      # window resize
      # bind = CTRL, q, exec, alacritty
    '';
    settings = {
      # "monitor" = ",preferred,auto,auto";
      "monitor" = "Virtual-1,1920x1080@60,0x0,1";
      "exec-once" = "nwg-dock-hyprland -r -p \"left\"";

      "$mainMod" = "CTRL";
      "env" = "WLR_NO_HARDWARE_CURSORS,1";

      input = {
        touchpad.disable_while_typing = false;
      };

      bind = let
        terminal = pkgs.alacritty;
      in [
        # Program bindings ${terminal}
        "$mainMod,q,exec,alacritty"
        "ALT,space,exec,rofi -show drun"
      ];
    };
  };
}
