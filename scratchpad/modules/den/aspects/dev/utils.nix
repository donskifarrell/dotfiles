{
  den.aspects.dev.utils = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.android-tools
          pkgs.bore-cli
          pkgs.devenv
          pkgs.glogg
          pkgs.insomnia
          pkgs.nixfmt-rfc-style
          pkgs.sqlitebrowser
        ];
      };
  };
}
