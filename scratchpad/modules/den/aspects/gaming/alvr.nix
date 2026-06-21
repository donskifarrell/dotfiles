# apps/gaming/alvr — PC-side VR streaming server.
#
# NOTE: `programs.alvr` is a NixOS (system) option, NOT a home-manager one, so
# this is a `nixos` aspect (like apps.gaming.steam). The legacy
# modules/home/alvr.nix filed it under home modules and used `programs.alvr`,
# which would have errored had it ever been activated — it never was, so the
# miscategorisation stayed dormant until home aspects began reaching the user.
{
  den.aspects.apps.gaming.alvr.nixos = _: {
    programs.alvr = {
      enable = true;
      openFirewall = true;
    };
  };
}
