{
  ...
}: {
  # Shared shell configuration
  # Smaller configs go here for now
  
  bat.enable = true;

  exa.enable = true;

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
}