# Ported from modules/system/printing.nix.
{
  den.aspects.desktop.printing.nixos = _: {
    services.printing.enable = true;
  };
}
