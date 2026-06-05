# Ported from modules/home/neovim.nix. Default editor.
{
  den.aspects.apps.dev.neovim.homeManager = {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
    };
    home.sessionVariables.EDITOR = "nvim";
  };
}
