# Ported from modules/system/appimage.nix. binfmt registration lets AppImages
# run directly.
{
  den.aspects.desktop.appimage.nixos = _: {
    programs.appimage = {
      enable = true;
      binfmt = true;
    };
  };
}
