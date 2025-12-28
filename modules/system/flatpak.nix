{
  config.flake.nixosModules.flatpak =
    { lib, ... }:
    {
      config = {
        services.flatpak = {
          enable = true;

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
      };
    };
}
