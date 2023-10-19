{pkgs, ...}: {
  # Shared shell configuration
  # Smaller configs go here for now

  home.stateVersion = "23.05";

  programs.bat.enable = true;

  programs.exa.enable = true;

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
