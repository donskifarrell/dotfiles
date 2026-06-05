# Ported from modules/home/zoxide.nix. Smarter `cd`.
{
  den.aspects.apps.shell.zoxide.homeManager = {
    programs.zoxide = {
      enable = true;
      enableFishIntegration = true;
    };
  };
}
