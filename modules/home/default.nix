{
  pkgs,
  ...
}:
{
  imports = [
    ./direnv.nix
    ./git.nix
    ./nix.nix
    ./ssh.nix
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

    firefox.enable = true;
    git.enable = true;
    vscode.enable = true;
  };

  home.packages = with pkgs; [
    age
  ];
}
