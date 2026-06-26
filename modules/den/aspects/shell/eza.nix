# Ported from modules/home/eza.nix. Modern `ls` (aliases live in apps.shell.fish).
{
  den.aspects.shell.eza.homeManager = {
    programs.eza = {
      enable = true;
      enableFishIntegration = true;
    };
  };
}
