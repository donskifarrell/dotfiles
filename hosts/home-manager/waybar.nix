{
  pkgs,
  lib,
  homeDir,
  configDir,
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
    file."waybar" = {
      source = "${homeDir}/.dotfiles/hosts/config/waybar";
      target = "${configDir}/waybar";
    };
  };

  # Run command in bash to see list of hardware sensors, for use in waybar
  # for i in /sys/class/hwmon/hwmon*/temp*_input; do echo "$(<$(dirname $i)/name): $(cat ${i%_*}_label 2>/dev/null || echo $(basename ${i%_*})) $(readlink -f $i)"; done
  programs.waybar.enable = true;
}
