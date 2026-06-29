# Re-export the private `mono` flake's NixOS modules as our own flake output.
{ inputs, ... }:
{
  flake.nixosModules = inputs.mono.nixosModules;
}
