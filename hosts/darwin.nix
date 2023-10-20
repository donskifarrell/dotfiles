{
  inputs,
  pkgs,
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
    ./modules/nixpkgs.nix

    ./modules
  ];

  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    autoMigrate = true;
    mutableTaps = true;
    user = "${user}";
    # taps = with inputs; {
    #   "homebrew/homebrew-core" = homebrew-core;
    #   "homebrew/homebrew-cask" = homebrew-cask;
    # };
  };
  homebrew = let
    pkgSets = import ./home-manager/packages.nix {inherit pkgs;};
  in {
    enable = true;

    onActivation = {
      cleanup = "uninstall";
      autoUpdate = true;
      upgrade = false;
    };

    global.autoUpdate = false;

    masApps = {
      # "An AppStore App" = 1234;
    };

    brews = pkgSets.osx-brews;

    caskArgs.no_quarantine = true;
    casks = pkgSets.osx-casks;
  };

  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;

  users.users.${user} = {
    name = "${user}";
    home = "/User/${user}";
  };

  home-manager = {
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

      # Different location on OSX
      home.homeDirectory = pkgs.lib.mkForce "/Users/${user}";

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
