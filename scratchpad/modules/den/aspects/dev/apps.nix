{ den, ... }:
{
  den.aspects.dev.apps = {
    includes = with den.aspects; [
      den.aspects.dev.vscode
    ];

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.android-tools
          pkgs.bore-cli
          pkgs.ctop
          pkgs.glogg
          pkgs.insomnia
          pkgs.mprocs
          pkgs.sqlitebrowser
        ];
      };
  };
}
