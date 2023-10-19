{
  pkgs,
  lib,
  ...
}: let
  hyprland-flake = builtins.getFlake "github:hyprwm/Hyprland";
in {
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
