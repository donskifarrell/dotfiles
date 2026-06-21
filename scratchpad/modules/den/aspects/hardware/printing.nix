# Ported from modules/system/printing.nix.
{
  den.aspects.hardware.printing.nixos = _: {
    services.printing.enable = true;
  };
}
