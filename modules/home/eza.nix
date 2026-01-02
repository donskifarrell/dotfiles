{
  config.flake.homeModules.eza = {
    config = {
      programs.eza = {
        enable = true;
        enableFishIntegration = true;
      };
    };
  };
}
