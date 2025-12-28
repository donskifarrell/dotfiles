{
  config.flake.homeModules.yazi = {
    config = {
      programs.yazi = {
        enable = true;
        enableFishIntegration = true;

        settings = {
          mgr = {
            show_hidden = true;
            sort_by = "natural";
            sort_dir_first = true;
          };
        };
      };
    };
  };
}
