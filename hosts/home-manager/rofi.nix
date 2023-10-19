{
  pkgs,
  lib,
  homeDir,
  configDir,
  ...
}: {
  home = {
    file."rofi" = {
      source = "${homeDir}/.dotfiles/hosts/config/rofi";
      target = "${configDir}/rofi";
    };
  };
}
