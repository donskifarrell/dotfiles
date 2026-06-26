# storage/disko — generic disko module wiring (reusable). The per-host disk
# layout itself is host data, declared in hosts/<name>.nix via `disko.devices`.
# Relocated from `core` into the `storage` category (filesystem/partitioning).
# Mirrors sini-nix's disk aspect.
{ inputs, ... }:
{
  den.aspects.hardware.storage.disko.nixos = {
    imports = [ inputs.disko.nixosModules.disko ];
  };
}
