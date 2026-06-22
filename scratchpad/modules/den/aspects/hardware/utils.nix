{
  den.aspects.hardware.utils = {
    os =
      { pkgs, ... }:
      {
        environment.systemPackages = [
          pkgs.lm_sensors
          pkgs.pciutils
          pkgs.usbutils
        ];
      };
  };
}
