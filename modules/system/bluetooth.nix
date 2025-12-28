{
  config.flake.nixosModules.bluetooth = _: {
    config = {
      hardware = {
        bluetooth.enable = true;
        bluetooth.powerOnBoot = true;
      };

      services.blueman.enable = true;
    };
  };
}
