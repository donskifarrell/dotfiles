# Generic, hardware-agnostic host tweaks that are safe on bare metal and in a VM.
# Not ported from a single legacy module — this is the small set of "every host
# wants these" knobs (periodic SSD trim + a little compressed swap). Kept
# conservative so it can sit on `short`'s host aspect without surprises.
{
  den.aspects.hardware.tweaks.nixos = _: {
    services.fstrim.enable = true;

    zramSwap = {
      enable = true;
      memoryPercent = 50;
    };
  };
}
