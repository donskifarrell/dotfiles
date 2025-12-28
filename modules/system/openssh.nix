{
  config.flake.nixosModules.openssh = _: {
    config = {
      services = {
        openssh = {
          enable = true;
          openFirewall = true;
        };
      };

      programs.ssh = {
        startAgent = true;
      };
    };
  };
}
