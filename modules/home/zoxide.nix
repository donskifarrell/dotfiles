{
  config.flake.homeModules.zoxide = {
    config = {
      programs.zoxide = {
        enable = true;
        enableFishIntegration = true;
      };
    };
  };
}
