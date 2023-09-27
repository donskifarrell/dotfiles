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

    file."electron25-flags.conf" = {
      source = "/home/${user}/.dotfiles/makati-nixos/config/electron25-flags.conf";
      target = "${xdg_configHome}/electron25-flags.conf";
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
        style = builtins.path {
          path = "/home/${user}/.dotfiles/makati-nixos/config/waybar/styles.css";
        };
        settings = {
          mainBar = {
            layer = "top";
            position = "top";
            height = 30;
            margin-top = 0;
            margin-left = 0;
            margin-right = 0;
            spacing = 0;

            modules-left = ["hyprland/workspaces" "hyprland/window"];
            "hyprland/workspaces" = {
              all-outputs = true;
              on-scroll-up = "hyprctl dispatch workspace e+1";
              on-scroll-down = "hyprctl dispatch workspace e-1";
            };
            "hyprland/window" = {
              format = "{title}";
              title-len = 30;
              rewrite = {
                "(.*) - Discord" = "󰙯  $1";
                "(.*) — Mozilla Firefox" = "  $1";
                "(.*) — File Explorer" = "  $1";
                "(.*) - Visual Studio Code" = "󰨞  $1";
              };
            };

            modules-center = ["custom/hyprpicker" "tray"];
            "custom/hyprpicker" = {
              format = "󰈋";
              on-click = "hyprpicker -a -f hex";
              on-click-right = "hyprpicker -a -f rgb";
            };
            "tray" = {
              icon-size = 16;
              spacing = 5;
              show-passive-items = true;
            };

            modules-right = [
              "keyboard-state"
              "disk"
              "cpu"
              "temperature"
              "memory"
              "network"
              "network#upload"
              "network#download"
              "bluetooth"
              "wireplumber"
              "clock"
              "custom/notification"
              "custom/power_btn"
            ];
            keyboard-state = {
              numlock = true;
              capslock = true;
              format = {
                numlock = " 󰎠";
                capslock = "󰪛 ";
              };
            };
            disk = {
              interval = "30";
              format = "{used}/{total}";
              path = "/";
            };
            cpu = {
              interval = 1;
              format = "  {usage}%";
              format-alt = "  {avg_frequency} GHz";
              on-click = "alacritty --title btop -e sh -c 'btop'";
            };
            temperature = {
              interval = 1;
              format = "  {temperatureC}󰔄";
            };
            memory = {
              format = "  {percentage}%";
              format-alt = "  {used}/{total} GiB";
              on-click = "alacritty --title btop -e sh -c 'btop'";
            };
            network = {
              interval = 1;
              format-wifi = "  {essid}";
              format-disconnected = "󰤭  OFFLINE";
              format-ethernet = "󰈀  ONLINE";
              format-alt = "{icon} {ifname}: {ipaddr}/{cidr}";
              tooltip-format = "{icon} {ifname}: {ipaddr}/{cidr}";
              on-click-right = "nm-connection-editor";
            };
            "network#upload" = {
              interval = 1;
              format = "󰅧  {bandwidthUpBytes}";
            };
            "network#download" = {
              interval = 1;
              format = "  {bandwidthDownBytes}";
            };
            bluetooth = {
              format = " {status}";
              format-connected = " {device_alias}";
              format-connected-battery = " {device_alias} {device_battery_percentage}%";
              # "format-device-preference" = [ "device1" "device2" ]; # preference list deciding the displayed device
              tooltip-format = "{controller_alias}\t{controller_address}\n\n{num_connections} connected";
              tooltip-format-connected = "{controller_alias}\t{controller_address}\n\n{num_connections} connected\n\n{device_enumerate}";
              tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
              tooltip-format-enumerate-connected-battery = "{device_alias}\t{device_address}\t{device_battery_percentage}%";
            };
            wireplumber = {
              format = "{icon}  {volume}%";
              # format = "  {volume}%";
              format-muted = "  {volume}%";
              format-icons = ["" "" ""];
            };
            clock = {
              format = "{:%a %b %d %H:%M %p}";
              tooltip-format = "<tt><small>{calendar}</small></tt>";
              calendar = {
                mode = "year";
                "mode-mon-col" = 3;
                "weeks-pos" = "right";
                "on-scroll" = 1;
                "on-click-right" = "mode";
                format = {
                  months = "<span color='#ffead3'><b>{}</b></span>";
                  days = "<span color='#ecc6d9'><b>{}</b></span>";
                  weeks = "<span color='#99ffdd'><b>W{}</b></span>";
                  weekdays = "<span color='#ffcc66'><b>{}</b></span>";
                  today = "<span color='#ff6699'><b><u>{}</u></b></span>";
                };
              };
              actions = {
                "on-click-right" = "mode";
                "on-click-forward" = "tz_up";
                "on-click-backward" = "tz_down";
                "on-scroll-up" = "shift_up";
                "on-scroll-down" = "shift_down";
              };
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
            "custom/power_btn" = {
              format = "";
              tooltip = false;
              "exec-if" = "which swaync-client";
              exec = "swaync-client -swb";
              "on-click" = "sleep 0.1; swaync-client -t -sw";
              "on-click-right" = "sleep 0.1; swaync-client -d -sw";
            };

            # Not placed yet
            mpris = {
              interval = 1;
              title-len = 30;
              format-playing = "󰝚  {dynamic}";
              format-paused = "  {dynamic}";
            };
          };
        };
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
