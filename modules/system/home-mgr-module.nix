{ inputs, ... }:
{
  config.flake.nixosModules.home-mgr-module =
    { config, claude-code, ... }:
    {
      imports = [
        inputs.home-manager.nixosModules.home-manager
      ];
      home-manager = {
        backupFileExtension = "backup";

        useGlobalPkgs = true;
        useUserPackages = true;

        extraSpecialArgs = {
          inherit claude-code;
          flakeHostname = config.my.flakeHostname;
        };
      };
    };
}
