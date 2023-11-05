{
  config,
  pkgs,
  ...
}: {
  # Shared home-manager configuration
  # Smaller configs go here for now

  home = {
    stateVersion = "23.05";

    sessionVariables = {
      LANG = "en_GB.UTF-8";
      LC_CTYPE = "en_GB.UTF-8";
      LC_ALL = "en_GB.UTF-8";
      PAGER = "less -FirSwX";
      MANPAGER = "sh -c 'col -bx | ${pkgs.bat}/bin/bat -l man -p'";
      MANROFFOPT = "-c";

      XDG_CACHE_DIR = "${config.home.homeDirectory}/.cache";
      XDG_CACHE_HOME = "${config.home.homeDirectory}/.cache";
      XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
      XDG_DATA_HOME = "${config.home.homeDirectory}/.local/share";
    };
  };

  fonts.fontconfig.enable = true;

  programs = {
    bat.enable = true;

    eza.enable = true;

    fzf.enable = true;

    zoxide = {
      enable = true;
      enableFishIntegration = true;
    };

    go = {
      enable = true;
      package = pkgs.go;
      goPath = "go";
    };
  };
}
