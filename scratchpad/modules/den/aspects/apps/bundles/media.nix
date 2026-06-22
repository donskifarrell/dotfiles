{
  den.aspects.apps.bundles.media = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.ffmpeg
          pkgs.imagemagick
          pkgs.krita
          pkgs.maestral-gui
          pkgs.vlc
        ];

        programs.obsidian.enable = true;
        programs.onlyoffice.enable = true;
      };
  };
}
