{
  config.flake.homeModules.ghostty = {
    config = {
      programs.ghostty = {
        enable = true;
        enableFishIntegration = true;
        installBatSyntax = true;
        systemd.enable = true;
      };
    };
  };
}
