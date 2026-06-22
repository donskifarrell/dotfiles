# Ported from modules/home/neovim.nix. Default editor.
{
  den.aspects.shell.neovim.homeManager = {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
    };

    home.sessionVariables.EDITOR = "nvim";
  };
}
