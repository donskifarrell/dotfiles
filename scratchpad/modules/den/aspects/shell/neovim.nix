# Ported from modules/home/neovim.nix. Default editor.
{
  den.aspects.shell.neovim.homeManager = {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
    };

    editor = "nvim";
    # home.sessionVariables.EDITOR = "nvim";
  };
}
