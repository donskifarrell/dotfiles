# Ported from modules/system/networking.nix
{
  den.aspects.core.networking.nixos = _: {
    networking = {
      networkmanager.enable = true;
      useNetworkd = false;
    };
  };
}
