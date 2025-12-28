{
  config.flake.homeModules.atuin = {
    config = {
      programs.atuin = {
        enable = true;
        enableFishIntegration = true;
        daemon.enable = true;
      };
    };
  };
}
