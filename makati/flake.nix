{
  description = "Home Manager configuration of df";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    nixpkgs,
    home-manager,
    ...
  }: let
    system = "x86_64-linux";
    hostname = "makati";
    homepath = "/home/df";
  in {
    nixosConfigurations = {
      specialArgs = {
        inherit
          system
          hostname
          ;
      };

      makati = nixpkgs.lib.nixosSystem {
        system = system;
        modules = [
          ./configuration.nix
          {
            networking.hostName = hostname;
          }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
          }
        ];
      };
    };

    homeConfigurations."df@makati" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${system};

      # Specify your home configuration modules here, for example,
      # the path to your home.nix.
      modules = [./home-df.nix];

      # Optionally use extraSpecialArgs
      # to pass through arguments to home.nix
      extraSpecialArgs = {
        inherit
          system
          hostname
          homepath
          ;
      };
    };
  };
}
