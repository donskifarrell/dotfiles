# Ported from modules/home/dev/distrobox.nix.
{
  den.aspects.dev.tools.distrobox.homeManager = {
    programs.distrobox.enable = true;
  };
}
