{
  den.aspects.dev.tools.devenv = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.devenv
        ];
      };
  };
}
