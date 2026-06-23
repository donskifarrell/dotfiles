# difftastic — structural diffs in git (modules/home/difftastic.nix)
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
