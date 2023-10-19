{
  pkgs,
  inputs,
  ...
}: let
  user = "df";
  hostname = "manila";
  system = "aarch64-darwin";
in {
  _module.args.user = user;
  _module.args.hostname = hostname;
  _module.args.system = system;

  nixpkgs.hostPlatform = system;

  imports = [
    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew

    ./modules/nix.nix
  ];

  nix-homebrew = {
    enable = true;
    user = "${user}";
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
    };
    mutableTaps = false;
    autoMigrate = true;
    cleanup = "uninstall";
  };

  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;

  users.users.${user} = {
    name = "${user}";
    home = "/User/${user}";
  };

  home-manager = {
    # Different location on OSX
    homeDirectory = pkgs.lib.mkForce "/Users/${config.home.username}";

    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs;
    };

    users.${user} = {pkgs, ...}: {
      _module.args.user = user;
      _module.args.hostname = hostname;
      _module.args.system = system;

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

      home.packages = let
        pkgSets = import ./home-manager/packages.nix {inherit pkgs;};
      in
        pkgSets.essentials-utils
        ++ pkgSets.essentials-dev
        ++ pkgSets.essentials-gui
        ++ pkgSets.osx;
    };
  };
}
