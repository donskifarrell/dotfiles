# Ported from modules/home/yazi.nix. TUI file manager.
{
  den.aspects.apps.shell.yazi.homeManager = {
    programs.yazi = {
      enable = true;
      enableFishIntegration = true;
      settings.mgr = {
        show_hidden = true;
        sort_by = "natural";
        sort_dir_first = true;
      };
    };
  };
}
