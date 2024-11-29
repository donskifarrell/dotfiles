{pkgs, ...}: {
  # environment.gnome.excludePackages = with pkgs; [
  #   gnome.totem
  #   gnome.epiphany
  #   gnome.gnome-calendar
  #   gnome.gnome-clocks
  #   gnome.gnome-contacts
  #   gnome.gnome-maps
  #   gnome.gnome-weather
  #   gnome.gnome-clocks
  # ];

  services = {
    desktopManager.plasma6.enable = true;

    xserver = {
      enable = true;

      displayManager = {
        gdm = {
          enable = true;
          wayland = true;
        };
      };

      # desktopManager.plasma6.debug = true;
    };

    # gnome = {
    #   sushi.enable = true;
    #   gnome-keyring.enable = true;
    # };
  };
}
