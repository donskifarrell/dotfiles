{
  den.aspects.hardware.firmware = {
    nixos = {
      hardware.enableRedistributableFirmware = true;
      hardware.enableAllFirmware = true;

      services.fwupd.enable = true;
    };
  };
}
