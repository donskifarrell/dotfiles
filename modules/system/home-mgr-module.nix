{ inputs, ... }:
{
  config.flake.nixosModules.home-mgr-module =
    { config, ... }:
    {
      imports = [
        inputs.home-manager.nixosModules.home-manager
      ];
      home-manager = {
        backupFileExtension = "backup";

        useGlobalPkgs = true;
        useUserPackages = true;

        extraSpecialArgs = {
          flakeHostname = config.my.flakeHostname;
        };
      };
    };
}
