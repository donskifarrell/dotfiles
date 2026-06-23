{
  den.aspects.core.desktop.xdg = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.xdg-utils
        ];

        xdg = {
          enable = true;

          # TODO: enable?
          # autostart.enable = true;
          userDirs.enable = true;
        };
      };
  };
}
