# apps/shell/archive — archive/extraction tooling (atool front-end + the
# common formats). Ported from sini-nix modules/den/aspects/apps/shell/archive.nix.
# Some of these overlap the my.packages catalog toggles (unzip/unrar/p7zip);
# home.packages dedupes identical store paths, so the overlap is harmless.
{
  den.aspects.shell.bundles.archive.homeManager =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.atool
        pkgs.p7zip
        pkgs.unrar
        pkgs.unzip
        pkgs.xz
        pkgs.zip
      ];
    };
}
