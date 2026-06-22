# apps/dev/git/lazygit — the lazygit TUI, plus an `lg` shell alias. Ported from
# sini-nix modules/den/aspects/apps/dev/git/lazygit.nix.
{
  den.aspects.dev.git.lazygit.homeManager = {
    programs.lazygit = {
      enable = true;
      settings = {
        gui.nerdFontsVersion = "3";
        git = {
          overrideGpg = true;
          log.order = "default";
          parseEmoji = true;
          commit.signOff = true;
          fetchAll = false;
        };
      };
    };

    home.shellAliases.lg = "lazygit";
  };
}
