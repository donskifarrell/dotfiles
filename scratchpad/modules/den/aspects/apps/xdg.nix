# Ported from modules/home/xdg.nix. XDG base dirs + user dirs.
{
  den.aspects.apps.xdg.homeManager =
    { config, ... }:
    let
      homeDir = config.home.homeDirectory;
    in
    {
      xdg = {
        autostart.enable = true;
        userDirs = {
          enable = true;
          music = "${homeDir}/music";
          documents = "${homeDir}/documents";
          desktop = "${homeDir}/desktop";
          pictures = "${homeDir}/pictures";
          download = "${homeDir}/download";
        };
      };

      home.sessionVariables = {
        XDG_CACHE_DIR = "${homeDir}/.cache";
        XDG_CACHE_HOME = "${homeDir}/.cache";
        XDG_CONFIG_HOME = "${homeDir}/.config";
        XDG_DATA_HOME = "${homeDir}/.local/share";
      };
    };
}
