# Ported from modules/system/appimage.nix. binfmt registration lets AppImages
# run directly.
{
  den.aspects.apps.appimage.nixos = _: {
    programs.appimage = {
      enable = true;
      binfmt = true;
    };
  };
}
