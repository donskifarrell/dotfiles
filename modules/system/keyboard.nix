{
  config.flake.nixosModules.keyboard = _: {
    config = {
      services = {
        xserver = {
          xkb = {
            layout = "us";
            variant = "";
          };
        };
      };
    };
  };
}
