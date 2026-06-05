# Ported from modules/system/cosmic.nix. Alternative DE to gnome — include one
# or the other on a desktop host, not both.
{
  den.aspects.desktop.cosmic.nixos = _: {
    services = {
      displayManager.cosmic-greeter.enable = true;
      desktopManager.cosmic.enable = true;
      desktopManager.cosmic.xwayland.enable = true;

      system76-scheduler.enable = true;

      gnome.gcr-ssh-agent.enable = false;
    };

    environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = 1;
  };
}
