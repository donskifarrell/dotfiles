{
  programs.nh = {
    enable = true;

    clean.enable = true;
    clean.dates = "weekly";
    clean.extraArgs = "--keep 5";

    # TODO: extract username to a top-level config
    flake = "/home/df/.dotfiles";
  };
}
