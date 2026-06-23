# Ported from modules/system/printing.nix.
{
  den.aspects.hardware.printing.nixos = _: {
    # Enable CUPS to print documents.
    services.printing.enable = true;
  };
}
