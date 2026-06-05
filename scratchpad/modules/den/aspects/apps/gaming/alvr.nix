# Ported from modules/home/alvr.nix. PC-side VR streaming server.
{
  den.aspects.apps.gaming.alvr.homeManager = {
    programs.alvr = {
      enable = true;
      openFirewall = true;
    };
  };
}
