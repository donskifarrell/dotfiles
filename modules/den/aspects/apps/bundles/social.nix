{
  den.aspects.apps.bundles.social = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.slack
          pkgs.telegram-desktop
        ];

        programs.element-desktop.enable = true;
      };
  };
}
