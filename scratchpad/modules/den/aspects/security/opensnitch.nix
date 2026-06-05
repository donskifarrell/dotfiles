# Ported from modules/system/opensnitch.nix. Application firewall daemon; the
# GUI prompt lives in the opensnitch-ui home aspect.
{
  den.aspects.security.opensnitch.nixos = _: {
    services.opensnitch.enable = true;
  };
}
