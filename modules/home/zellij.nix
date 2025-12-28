{
  config.flake.homeModules.zellij = {
    config = {
      programs.zellij = {
        enable = true;
        enableFishIntegration = true;
        exitShellOnExit = true;
        attachExistingSession = true;
        settings = {
          show_startup_tips = true;
          theme = "solarized-dark";
        };
      };
    };
  };
}
