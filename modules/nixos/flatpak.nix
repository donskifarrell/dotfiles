{
  lib,
  ...
}:
{
  services = {
    flatpak = {
      enable = true;

      remotes = lib.mkOptionDefault [
        {
          name = "flathub";
          location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
        }
      ];

      update.auto.enable = false;
      uninstallUnmanaged = false;

      packages = [
      ];
    };
  };
}
