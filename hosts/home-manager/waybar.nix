{
  pkgs,
  lib,
  ...
}: {
  nixpkgs = {
    overlays = [
      (self: super: {
        waybar = super.waybar.overrideAttrs (oldAttrs: {
          mesonFlags = oldAttrs.mesonFlags ++ ["-Dexperimental=true"];
        });
      })
    ];
  };

  home = {
    sessionVariables = {
      XDG_CONFIG_HOME = "${XDG_CONFIG_HOME}";
    };

    file."waybar" = {
      # TODO: Fix directory
      source = "/home/${user}/.dotfiles/makati-nixos/config/waybar";
      target = "${XDG_CONFIG_HOME}/waybar";
    };
  };

  # Run command in bash to see list of hardware sensors, for use in waybar
  # for i in /sys/class/hwmon/hwmon*/temp*_input; do echo "$(<$(dirname $i)/name): $(cat ${i%_*}_label 2>/dev/null || echo $(basename ${i%_*})) $(readlink -f $i)"; done
  programs.waybar.enable = true;
}
