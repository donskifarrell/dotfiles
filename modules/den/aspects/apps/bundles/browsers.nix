{
  den.aspects.apps.bundles.browsers = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.brave
          pkgs.chromium
          pkgs.firefox
          pkgs.vivaldi
        ];
      };
  };
}
