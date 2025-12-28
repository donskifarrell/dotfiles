{
  config.flake.homeModules.neovim = {
    config = {
      programs.neovim = {
        enable = true;
        defaultEditor = true;
      };

      home = {
        sessionVariables = {
          EDITOR = "nvim";
        };
      };
    };
  };
}
