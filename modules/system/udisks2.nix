{
  config.flake.nixosModules.udisks2 = _: {
    config = {
      services.udisks2.enable = true;
    };
  };
}
