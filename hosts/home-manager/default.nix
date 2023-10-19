{
  pkgs,
  homeDir,
  configDir,
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

      XDG_CACHE_DIR = "${homeDir}/.cache";
      XDG_CACHE_HOME = "${homeDir}/.cache";
      XDG_CONFIG_HOME = "${configDir}";
      XDG_DATA_HOME = "${homeDir}/.local/share";
    };
  };

  fonts.fontconfig.enable = true;

  programs.bat.enable = true;

  programs.eza.enable = true;

  programs.fzf.enable = true;

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.go = {
    enable = true;
    package = pkgs.go;
    goPath = "go";
  };
}
