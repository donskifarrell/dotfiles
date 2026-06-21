# Ported from modules/system/appimage.nix. binfmt registration lets AppImages
# run directly.
{
  den.aspects.core.apps.appimage.nixos = _: {
    programs.appimage = {
      enable = true;
      binfmt = true;
    };
  };
}
