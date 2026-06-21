# Ported from modules/system/touchpad.nix.
{
  den.aspects.hardware.touchpad.nixos = _: {
    services.libinput.enable = true;
  };
}
