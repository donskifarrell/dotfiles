# Ported from modules/home/zellij.nix. Terminal multiplexer.
{
  den.aspects.shell.zellij.homeManager = {
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
}
