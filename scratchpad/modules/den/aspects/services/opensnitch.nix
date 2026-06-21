{
  den.aspects.services.opensnitch = {
    nixos =
      { host, ... }:
      {
        services.opensnitch.enable = true;
      };

    homeManager =
      { host, ... }:
      {
        services.opensnitch-ui.enable = true;
      };
  };
}
