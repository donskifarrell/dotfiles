{
  config.flake.nixosModules.avahi = _: {
    config = {
      services = {
        avahi.enable = true;
      };
    };
  };
}
