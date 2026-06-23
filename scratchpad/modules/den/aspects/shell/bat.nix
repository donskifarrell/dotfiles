# apps/dev/shell/bat — bat (a better `cat`) with the bat-extras helpers
# (batman, batgrep, batdiff, …). Ported from sini-nix
# modules/den/aspects/apps/dev/shell/bat.nix.
#
# NB: the `cat = bat` shell alias already lives in apps.shell.fish, so it is
# intentionally NOT redefined here (a second `cat` key would collide). This is a
# richer superset of the bare `bat.enable` in apps.cli (they merge fine).
{
  den.aspects.shell.bat.homeManager =
    { pkgs, ... }:
    {
      programs.bat = {
        enable = true;
        config.style = "plain";
        extraPackages = with pkgs.bat-extras; [
          prettybat
          batwatch
          batpipe
          batman
          batgrep
          batdiff
        ];
      };
    };
}
