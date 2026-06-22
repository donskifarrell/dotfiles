{
  den.aspects.apps.bundles.media = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs._1password-cli
          pkgs._1password-gui
          pkgs.authenticator
        ];
      };
  };
}
