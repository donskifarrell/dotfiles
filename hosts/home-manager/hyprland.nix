{
  pkgs,
  lib,
  homeDir,
  configDir,
  ...
}: let
  hyprland-flake = builtins.getFlake "github:hyprwm/Hyprland";
in {
  home = {
    file."wlogout" = {
      source = "${homeDir}/.dotfiles/hosts/config/wlogout";
      target = "${configDir}/wlogout";
    };
    file."swaync" = {
      source = "${homeDir}/.dotfiles/hosts/config/swaync";
      target = "${configDir}/swaync";
    };
    file."sway-lock" = {
      source = "${homeDir}/.dotfiles/hosts/config/sway-lock";
      target = "${configDir}/sway-lock";
    };
    file."electron25-flags.conf" = {
      source = "${homeDir}/.dotfiles/hosts/config/electron25-flags.conf";
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
