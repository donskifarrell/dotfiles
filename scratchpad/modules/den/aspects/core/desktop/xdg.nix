{
  den.aspects.core.desktop.xdg = {
    homeManager =
      { config, pkgs, ... }:
      {
        home.packages = [
          pkgs.xdg-utils
        ];

        xdg = {
          enable = true;

          # TODO: enable?
          # autostart.enable = true;
          userDirs = {
            enable = true;
            music = "${config.home.homeDirectory}/music";
            documents = "${config.home.homeDirectory}/documents";
            desktop = "${config.home.homeDirectory}/desktop";
            pictures = "${config.home.homeDirectory}/pictures";
            download = "${config.home.homeDirectory}/download";
          };
        };
      };
  };
}
