# Ported from modules/system/flatpak.nix.
{
  den.aspects.services.flatpak.nixos = _: {
    services.flatpak.enable = true;

    # From: nix-flatpak.url = "github:gmodena/nix-flatpak";
    # remotes = lib.mkOptionDefault [
    #   {
    #     name = "flathub";
    #     location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
    #   }
    # ];

    # update.auto.enable = false;
    # uninstallUnmanaged = false;
  };
}
