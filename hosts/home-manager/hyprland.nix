{
  config,
  lib,
  pkgs,
  ...
}: let
  hyprland-flake = builtins.getFlake "github:hyprwm/Hyprland";
in {
  home = let
    configDir = "${config.home.homeDirectory}/.config";
  in {
    file."wlogout" = {
      source = "${config.home.homeDirectory}/.dotfiles/hosts/config/wlogout";
      target = "${configDir}/wlogout";
    };
    file."swaync" = {
      source = "${config.home.homeDirectory}/.dotfiles/hosts/config/swaync";
      target = "${configDir}/swaync";
    };
    file."sway-lock" = {
      source = "${config.home.homeDirectory}/.dotfiles/hosts/config/sway-lock";
      target = "${configDir}/sway-lock";
    };
    file."electron25-flags.conf" = {
      source = "${config.home.homeDirectory}/.dotfiles/hosts/config/electron25-flags.conf";
      target = "${configDir}/electron25-flags.conf";
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
