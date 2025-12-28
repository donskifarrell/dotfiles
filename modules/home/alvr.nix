{
  config.flake.homeModules.alvr = {
    config = {
      programs.alvr = {
        enable = true;
        openFirewall = true;
      };
    };
  };
}
