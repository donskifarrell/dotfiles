# Generic disko module wiring (reusable). The per-host disk layout is host
# data, set in hosts/<name>.nix via `disko.devices`. Mirrors sini-nix's
# core.system.disko aspect.
{ inputs, ... }:
{
  den.aspects.core.disko.nixos = {
    imports = [ inputs.disko.nixosModules.disko ];
  };
}
