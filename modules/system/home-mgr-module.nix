{ inputs, ... }:
{
  config.flake.nixosModules.home-mgr-module =
    { ... }:
    {
      imports = [
        inputs.home-manager.nixosModules.home-manager
      ];
      home-manager = {
        backupFileExtension = "backup";

        useGlobalPkgs = true;
        useUserPackages = true;
      };
    };
}
