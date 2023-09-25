{
  pkgs,
  lib,
  inputs,
  ...
}: let
  user = "df";
  xdg_configHome = "/home/${user}/.config";
  packages = pkgs.callPackage ./packages.nix {};
  themes = pkgs.callPackage ./config/rofi-themes.nix {};
  shared-programs = import ../shared/home-manager.nix {inherit pkgs lib;};
  # shared-files = import ../shared/files.nix {inherit config pkgs;};

  hyprland-flake = builtins.getFlake "github:hyprwm/Hyprland";
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
        settings = {
          mainBar = {
            layer = "top";
            position = "top";
            height = 30;
            # output = [
            #   "eDP-1"
            #   "HDMI-A-1"
            # ];
            # modules-left = ["sway/workspaces" "sway/mode" "wlr/taskbar"];
            # modules-center = ["sway/window" "custom/hello-from-waybar"];
            # modules-right = ["mpd" "custom/mymodule#with-css-id" "temperature"];

            # "sway/workspaces" = {
            #   disable-scroll = true;
            #   all-outputs = true;
            # };
            "custom/hello-from-waybar" = {
              format = "hello {}";
              max-length = 40;
              interval = "once";
              exec = pkgs.writeShellScript "hello-from-waybar" ''
                echo "from within waybar"
              '';
            };

            "custom/notification" = {
              tooltip = false;
              format = "{icon}";
              format-icons = {
                notification = "<span foreground='red'><sup></sup></span>";
                none = "";
                dnd-notification = "<span foreground='red'><sup></sup></span>";
                dnd-none = "";
                inhibited-notification = "<span foreground='red'><sup></sup></span>";
                inhibited-none = "";
                dnd-inhibited-notification = "<span foreground='red'><sup></sup></span>";
                dnd-inhibited-none = "";
              };
              return-type = "json";
              exec-if = "which swaync-client";
              exec = "swaync-client -swb";
              on-click = "swaync-client -t -sw";
              on-click-right = "swaync-client -d -sw";
              escape = true;
            };
          };
        };
        style = "~/.dotfiles/makati-nixos/config/waybar/styles.css";
      };
    };

  wayland.windowManager.hyprland = {
    enable = true;
    package = hyprland-flake.packages.${pkgs.system}.hyprland;
    enableNvidiaPatches = false;
    systemdIntegration = true;
    xwayland.enable = true;

    settings = {
      "source" = "~/.dotfiles/makati-nixos/config/hyprland/hyprland.conf";
    };
  };
}
