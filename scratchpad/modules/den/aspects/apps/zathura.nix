# apps/productivity/zathura — keyboard-driven PDF/document viewer. Ported from
# sini-nix modules/den/aspects/apps/productivity/zathura.nix.
{
  den.aspects.apps.zathura.homeManager = {
    programs.zathura = {
      enable = true;
      options = {
        guioptions = "v";
        adjust-open = "width";
        statusbar-basename = true;
        render-loading = false;
        scroll-step = 120;
        selection-clipboard = "clipboard";
      };
    };
  };
}
