{
  config.flake.homeModules.tailscale = {
    config = {
      services.tailscale-systray.enable = true;
    };
  };
}
