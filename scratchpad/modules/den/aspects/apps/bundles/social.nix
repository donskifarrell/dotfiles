{
  den.aspects.apps.bundles.social = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.slack
        ];

        programs.element-desktop.enable = true;
      };
  };
}
