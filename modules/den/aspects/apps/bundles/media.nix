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

        # obsidian moved to the dedicated apps.obsidian aspect (vault wiring).
        programs.onlyoffice.enable = true;
      };
  };
}
