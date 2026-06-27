{
  den.aspects.services.opensnitch = {
    nixos = _: {
      services.opensnitch.enable = true;
    };

    homeManager = _: {
      services.opensnitch-ui.enable = true;
    };
  };
}
