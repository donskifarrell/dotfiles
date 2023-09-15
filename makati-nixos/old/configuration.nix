# This is your system's configuration file.
# Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [
    # If you want to use modules from other flakes (such as nixos-hardware), use something like:
    # inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-ssd

    # It's strongly recommended you take a look at
    # https://github.com/nixos/nixos-hardware
    # and import modules relevant to your hardware.

    # Import your generated (nixos-generate-config) hardware configuration
    ./hardware-configuration.nix
  ];

  environment.gnome.excludePackages = with pkgs; [
    gnome.totem
    gnome.epiphany
    gnome.gnome-calendar
    gnome.gnome-clocks
    gnome.gnome-contacts
    gnome.gnome-maps
    gnome.gnome-weather
    gnome.gnome-clocks
  ];
}
