# Ported from modules/home/ghostty.nix.
{
  den.aspects.apps.terminals.ghostty.homeManager = {
    programs.ghostty = {
      enable = true;
      enableFishIntegration = true;
      installBatSyntax = true;
      systemd.enable = true;
      settings.shell-integration-features = "ssh-terminfo";
    };
  };
}
