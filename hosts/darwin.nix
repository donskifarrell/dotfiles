{
  inputs,
  pkgs,
  ...
}: let
  user = "df";
  hostname = "manila";
  system = "aarch64-darwin";
  homeDir =
    if pkgs.stdenv.isLinux
    then "/home/${user}"
    else if pkgs.stdenv.isDarwin
    then "/Users/${user}"
    else throw "Unsupported platform";
in {
  _module.args = {
    inherit user hostname system homeDir;
  };

  nixpkgs.hostPlatform = system;

  imports = [
    inputs.agenix.nixosModules.default
    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew

    ./modules/nix.nix
    ./modules/nixpkgs.nix

    ./modules
    ./modules/agenix.nix
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

  environment.shells = [pkgs.fish];

  users.users.${user} = {
    name = "${user}";
    home = "/Users/${user}";
  };

  home-manager = {
    useGlobalPkgs = true;
    # useUserPackages = true; # If enabled, then home-manager apps aren't linked properly to /Users/X/.nix-profile/..
    extraSpecialArgs = {
      inherit inputs;
    };

    users.${user} = {pkgs, ...}: {
      _module.args = {
        inherit user hostname system;
      };

      imports = [
        ./home-manager
        ./home-manager/alacritty.nix
        ./home-manager/btop.nix
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
        ++ pkgSets.osx
        ++ [
          inputs.agenix.packages."${pkgs.system}".default
        ];
    };
  };
}
