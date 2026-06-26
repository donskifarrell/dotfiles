# apps/dev/lang/python — a baseline Python 3 interpreter on PATH. Ported from
# sini-nix modules/den/aspects/apps/dev/lang/python.nix. (Per-project Python is
# better handled via direnv/devenv; this is just the always-available fallback.)
{
  den.aspects.dev.lang.python.homeManager =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.python3 ];
    };
}
