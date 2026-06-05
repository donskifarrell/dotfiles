# Ported from modules/home/atuin.nix. Shell history sync (fish integration).
{
  den.aspects.apps.shell.atuin.homeManager = {
    programs.atuin = {
      enable = true;
      enableFishIntegration = true;
      daemon.enable = true;
      flags = [ "--disable-up-arrow" ];
    };
  };
}
