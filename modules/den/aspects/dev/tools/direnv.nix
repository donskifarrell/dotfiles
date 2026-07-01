# Ported from modules/home/dev/direnv.nix.
{
  den.aspects.dev.tools.direnv.homeManager = { config, ... }: {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      config.global.hide_env_diff = true;
      config.whitelist = { };
      enableBashIntegration = true;
      enableFishIntegration = config.programs.fish.enable;
    };
  };
}
