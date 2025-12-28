{
  config.flake.homeModules.udiskie = {
    config = {
      services.udiskie = {
        enable = true;
      };
    };
  };
}
