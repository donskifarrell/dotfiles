{
  config.flake.nixosModules.gnome =
    { pkgs, ... }:
    {
      config = {
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
            gcr-ssh-agent.enable = false;
          };

          gvfs.enable = true; # Mount, trash, and other functionalities
          tumbler.enable = true; # Thumbnail support for images
        };

        xdg = {
          portal = {
            enable = true;
            # wlr.enable = true;
            extraPortals = [
              pkgs.xdg-desktop-portal-gnome
              pkgs.xdg-desktop-portal-gtk
            ];

            config.common.default = [
              "gnome"
              "gtk"
            ];

            xdgOpenUsePortal = true;
          };
        };

        programs.dconf.enable = true;

        environment.systemPackages = with pkgs; [
          gnome-extension-manager
          # gnomeExtensions.allow-locked-remote-desktop
          gnomeExtensions.blur-my-shell
          gnomeExtensions.appindicator
          gnomeExtensions.caffeine
          gnomeExtensions.dash-to-dock
          gnomeExtensions.just-perfection
          gnomeExtensions.pop-shell
          gnomeExtensions.vitals
        ];
      };
    };
}
