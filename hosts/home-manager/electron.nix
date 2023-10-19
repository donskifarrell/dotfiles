{
  pkgs,
  lib,
  homeDir,
  configDir,
  ...
}: {
  home = {
    file."electron25-flags.conf" = {
      source = "${homeDir}/.dotfiles/hosts/config/electron25-flags.conf";
      target = "${configDir}/electron25-flags.conf";
    };
  };
}
