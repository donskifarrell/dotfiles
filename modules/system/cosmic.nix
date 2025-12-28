{
  config.flake.nixosModules.cosmic =
    { pkgs, ... }:
    {
      config = {
        services = {
          displayManager.cosmic-greeter.enable = true;
          desktopManager.cosmic.enable = true;
          desktopManager.cosmic.xwayland.enable = true;

          system76-scheduler.enable = true;
        };

        environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = 1;

        services.gnome.gcr-ssh-agent.enable = false;
      };
    };
}
