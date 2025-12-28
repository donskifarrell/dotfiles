{
  config.flake.nixosModules.opensnitch = {
    config = {
      services.opensnitch.enable = true;
    };
  };
}
