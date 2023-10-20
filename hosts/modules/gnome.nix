{
  inputs,
  nixpkgs,
  pkgs,
  ...
}: {
  nixpkgs.overlays = [
    (self: super: {
      gnome = inputs.gnomeNixpkgs.legacyPackages.x86_64-linux.gnome;
    })
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

  services = {
    xserver = {
      enable = true;
      desktopManager.gnome.enable = true;
    };
    gnome = {
      sushi.enable = true;
      gnome-keyring.enable = true;
    };
  };
}
