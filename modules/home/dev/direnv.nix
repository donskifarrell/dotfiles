{
  config.flake.homeModules.direnv = {
    config = {
      programs.direnv = {
        enable = true;

        nix-direnv.enable = true;

        config.global = {
          hide_env_diff = true;
        };

        config.whitelist = {
        };
      };
    };
  };
}
