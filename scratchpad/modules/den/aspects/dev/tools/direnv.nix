# Ported from modules/home/dev/direnv.nix.
{
  den.aspects.dev.tools.direnv.homeManager = {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      config.global.hide_env_diff = true;
      config.whitelist = { };
    };
  };
}
