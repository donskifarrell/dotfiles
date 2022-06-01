# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)

{ inputs, lib, config, pkgs, hostname, ... }: {
  imports = [
    # If you want to use home-manager modules from other flakes (such as nix-colors), use something like:
    # inputs.nix-colors.homeManagerModule

    # Feel free to split up your configuration and import pieces of it here.
    ../common/home-base.nix
  ];

  home.packages = [
    pkgs.go
    pkgs.gopls

    pkgs.ffmpeg
  ];

  programs.git = {
    includes = [
      { path = "~/.dotfiles/hosts/${hostname}/.gitconfig.local"; }
      {
        path = ".gitconfig.brankas";
        condition = "gitdir/i:brankas/";
      }
      {
        path = ".gitconfig.brankas";
        condition = "gitdir/i:brank.as/";
      }
    ];
  };
}