{ den, ... }:
{
  den.aspects.dev.apps = {
    includes = [
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
