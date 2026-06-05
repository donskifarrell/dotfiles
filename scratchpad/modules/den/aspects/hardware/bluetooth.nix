# Ported from modules/system/bluetooth.nix. blueman applet pairs with a desktop.
{
  den.aspects.hardware.bluetooth.nixos = _: {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    services.blueman.enable = true;
  };
}
