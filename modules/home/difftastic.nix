{
  config.flake.homeModules.difftastic = {
    config = {
      programs.difftastic = {
        enable = true;
        git.enable = true;
      };
    };
  };
}
