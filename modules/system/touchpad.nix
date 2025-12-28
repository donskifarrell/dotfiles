{
  config.flake.nixosModules.touchpad = _: {
    config = {
      services.libinput.enable = true;
    };
  };
}
