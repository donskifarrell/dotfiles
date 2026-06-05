# Ported from modules/home/dev/distrobox.nix.
{
  den.aspects.apps.dev.distrobox.homeManager = {
    programs.distrobox.enable = true;
  };
}
