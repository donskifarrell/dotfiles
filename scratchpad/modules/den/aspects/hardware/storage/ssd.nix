{
  den.aspects.hardware.storage.ssd = {
    nixos = {
      services.fstrim = {
        enable = true;
        interval = "weekly";
      };
    };
  };
}
