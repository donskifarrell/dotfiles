{
  config,
  pkgs,
  ...
}: {
  # Shared home-manager configuration
  # Smaller configs go here for now


  # fonts.fontconfig.enable = true;

  programs = {
    bat.enable = true;

    direnv.enable = true;

    eza.enable = true;

    fzf.enable = true;

    zoxide = {
      enable = true;
      enableFishIntegration = true;
    };

    go = {
      enable = true;
      package = pkgs.go;
      goPath = "dev";
      goBin = "dev/bin";
    };
  };
}
