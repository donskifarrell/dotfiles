# Generic facter wiring (reusable). The per-host report path is host data,
# set in hosts/<name>.nix via `facter.reportPath`. Mirrors sini-nix's
# core.system.facter aspect.
{ inputs, ... }:
{
  den.aspects.core.facter.nixos = {
    imports = [ inputs.nixos-facter-modules.nixosModules.facter ];

    # Let our explicit aspects own these rather than facter's auto-detection
    # (we drive networking via NetworkManager in core.networking).
    facter.detected = {
      dhcp.enable = false;
      graphics.enable = false;
    };
  };
}
