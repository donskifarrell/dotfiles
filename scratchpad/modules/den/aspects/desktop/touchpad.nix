# Ported from modules/system/touchpad.nix.
{
  den.aspects.desktop.touchpad.nixos = _: {
    services.libinput.enable = true;
  };
}
