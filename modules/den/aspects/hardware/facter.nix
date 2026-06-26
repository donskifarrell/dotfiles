# Generic facter wiring (reusable). The per-host report path is host data,
# set in hosts/<name>.nix via `facter.reportPath`
{ inputs, ... }:
{
  den.aspects.hardware.facter.nixos = {
    imports = [ inputs.nixos-facter-modules.nixosModules.facter ];

    # Let our explicit aspects own these rather than facter's auto-detection
    # (we drive networking via NetworkManager in networking.networkmanager).
    facter.detected = {
      dhcp.enable = false;
      graphics.enable = false;
    };
  };
}
