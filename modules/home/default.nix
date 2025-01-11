{
  imports = [
    ./agenix.nix
    ./direnv.nix
    ./ssh.nix
    ./nix.nix
  ];

  programs = {
    bat.enable = true;
    direnv.enable = true;
    eza.enable = true;
    fish.enable = true;
    fzf.enable = true;

    zoxide = {
      enable = true;
      enableFishIntegration = true;
    };
  };
}
