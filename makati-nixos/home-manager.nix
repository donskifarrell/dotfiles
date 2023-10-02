{
  pkgs,
  lib,
  inputs,
  ...
}: let
  user = "df";
  homeDir = "/home/${user}";
  XDG_CACHE_HOME = "${homeDir}/.cache";
  XDG_CONFIG_HOME = "${homeDir}/.config";
  XDG_DATA_HOME = "${homeDir}/.local/share";

  packages = pkgs.callPackage ./packages.nix {};
  shared-programs = import ../shared/home-manager.nix {inherit pkgs lib;};
  # shared-files = import ../shared/files.nix {inherit config pkgs;};

  hyprland-flake = builtins.getFlake "github:hyprwm/Hyprland";
in {
  home = {
    enableNixpkgsReleaseCheck = false;
    username = "${user}";
    homeDirectory = "${homeDir}";
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
      XDG_CACHE_DIR = "${XDG_CACHE_HOME}";
      XDG_CACHE_HOME = "${XDG_CACHE_HOME}";
      XDG_CONFIG_HOME = "${XDG_CONFIG_HOME}";
      XDG_DATA_HOME = "${XDG_DATA_HOME}";
    };

    file."fish-catppuccin-macchiato" = {
      source = "/home/${user}/.dotfiles/shared/config/theme/fish-catppuccin-macchiato.theme";
      target = "${XDG_CONFIG_HOME}/fish/themes/fish-catppuccin-macchiato.theme";
    };
    file."rofi" = {
      source = "/home/${user}/.dotfiles/makati-nixos/config/rofi";
      target = "${XDG_CONFIG_HOME}/rofi";
    };
    file."waybar" = {
      source = "/home/${user}/.dotfiles/makati-nixos/config/waybar";
      target = "${XDG_CONFIG_HOME}/waybar";
    };
    file."wlogout" = {
      source = "/home/${user}/.dotfiles/makati-nixos/config/wlogout";
      target = "${XDG_CONFIG_HOME}/wlogout";
    };
    file."swaync" = {
      source = "/home/${user}/.dotfiles/makati-nixos/config/swaync";
      target = "${XDG_CONFIG_HOME}/swaync";
    };
    file."sway-lock" = {
      source = "/home/${user}/.dotfiles/makati-nixos/config/sway-lock";
      target = "${XDG_CONFIG_HOME}/sway-lock";
    };
    file."electron25-flags.conf" = {
      source = "/home/${user}/.dotfiles/makati-nixos/config/electron25-flags.conf";
      target = "${XDG_CONFIG_HOME}/electron25-flags.conf";
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

  gtk = let
    gtkExtra = {
      gtk-application-prefer-dark-theme = 1;
    };
  in {
    enable = true;
    cursorTheme = {
      name = "capitaine-cursors";
      size = 24;
    };
    iconTheme = {
      name = "Adwaita";
    };
    font = {
      name = "Cantarell 11";
    };
    theme = {
      name = "Catppuccin-Macchiato";
      package = pkgs.catppuccin-gtk.override {
        # accents = ["pink"];
        # size = "compact";
        # tweaks = ["rimless" "black"];
        variant = "macchiato";
      };
    };
    gtk3.extraConfig = gtkExtra;
    gtk4.extraConfig = gtkExtra;
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
    playerctld.enable = true;
  };

  programs =
    shared-programs
    // {
      # Run command in bash to see list of hardware sensors
      # for i in /sys/class/hwmon/hwmon*/temp*_input; do echo "$(<$(dirname $i)/name): $(cat ${i%_*}_label 2>/dev/null || echo $(basename ${i%_*})) $(readlink -f $i)"; done
      waybar.enable = true;
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
