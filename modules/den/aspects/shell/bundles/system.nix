# apps/shell/disk — disk-usage explorers (dua, dysk, ncdu).
{
  den.aspects.shell.bundles.system.homeManager =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.btop
        pkgs.busybox
        pkgs.dua
        pkgs.dysk
        pkgs.ncdu
      ];

      programs.htop.enable = true;
    };
}
