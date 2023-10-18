{
  pkgs,
  inputs,
  homebrew-core,
  homebrew-cask,
  ...
}: let
  user = "df";
  hostname = "manila";
in {
  _module.args.user = user;
  _module.args.hostname = hostname;

  imports = [
    home-manager.darwinModules.home-manager
    nix-homebrew.darwinModules.nix-homebrew

    ./modules/nix.nix
  ];

  nix-homebrew = {
    enable = true;
    user = "${user}";
    taps = {
      "homebrew/homebrew-core" = homebrew-core;
      "homebrew/homebrew-cask" = homebrew-cask;
    };
    mutableTaps = false;
    autoMigrate = true;
  };

  imports = [ <home-manager/nix-darwin> ];

  users.users.${user} = {
    name = "${user}";
    home = "/User/${user}";
  }

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${user} = { pkgs, …}: {
      imports = [
        ./home-manager
        ./home-manager/alacritty.nix
        ./home-manager/fish.nix
        ./home-manager/git.nix
        ./home-manager/neovim.nix
        ./home-manager/ssh.nix
        ./home-manager/starship.nix
        ./home-manager/tmux.nix
        ./home-manager/vscode.nix
      ];

      home.packages = let pkgSets = import ./home-manager/packages.nix; in
        pkgSets.essentials-utils
        ++ pkgSets.essentials-dev
        ++ pkgSets.essentials-gui
        ++ pkgSets.osx
    };
  }
}
