# apps/shell/data — data-wrangling CLI (file, wget, dig, yq, tokei) plus jq,
# navi cheatsheets, tealdeer (tldr), and lazysql. Ported from sini-nix
# modules/den/aspects/apps/shell/data.nix; shell integration scoped to fish.
{
  den.aspects.shell.bundles.data.homeManager =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.exiftool
        pkgs.tokei
        pkgs.yq
      ];

      programs = {
        jq.enable = true;

        navi = {
          enable = true;
          enableFishIntegration = true;
        };

        tealdeer = {
          enable = true;
          settings.updates.auto_update = true;
        };

        lazysql.enable = true;
      };
    };
}
