# Ported from modules/system/gnome.nix. GNOME on Wayland (GDM) + portals,
# dconf, and a curated extension set.
{
  den.aspects.services.gnome.nixos =
    { pkgs, ... }:
    {
      services = {
        xserver.enable = true;

        displayManager.gdm.enable = true;

        desktopManager.gnome.enable = true;

        gnome = {
          sushi.enable = true;
          gnome-keyring.enable = true;
          gcr-ssh-agent.enable = false;
        };

        gvfs.enable = true; # Mount, trash, and other functionalities
        tumbler.enable = true; # Thumbnail support for images
      };

      xdg.portal = {
        enable = true;
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

      programs.dconf.enable = true;

      environment.systemPackages = with pkgs; [
        gnome-extension-manager
        gnomeExtensions.blur-my-shell
        gnomeExtensions.appindicator
        gnomeExtensions.caffeine
        gnomeExtensions.dash-to-dock
        gnomeExtensions.just-perfection
        gnomeExtensions.pop-shell
        gnomeExtensions.vitals
        wl-clipboard # wl-copy/wl-paste: CLI clipboard for TUIs (herdr copy-on-select)
      ];
    };

  # Mutter lacks (ext|wlr)-data-control, so every wl-copy maps a tiny focus-stealing
  # window (wl-clipboard#90); pop-shell auto-tiles it, resizing the terminal on each
  # herdr copy. Float it. Read-only: pop-shell's exceptions dialog can't save edits.
  den.aspects.services.gnome.homeManager.xdg.configFile."pop-shell/config.json".text =
    builtins.toJSON
      {
        float = [ { class = "io.github.bugaevc.wl-clipboard"; } ];
        skiptaskbarhidden = [ ];
        log_on_focus = false;
      };
}
