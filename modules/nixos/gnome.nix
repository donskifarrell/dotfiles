{ pkgs, ... }:
{
  services = {
    xserver.enable = true;

    displayManager = {
      gdm = {
        enable = true;
        wayland = true;
      };
    };

    desktopManager.gnome.enable = true;

    gnome = {
      sushi.enable = true;
      gnome-keyring.enable = true;
    };

    gvfs.enable = true; # Mount, trash, and other functionalities
    tumbler.enable = true; # Thumbnail support for images
  };

  environment.systemPackages = with pkgs; [
    # This is necessary to set CAPS to CTRL
    # gnome-tweaks
  ];

  programs = {
    dconf.enable = true;
  };
}
