# den → clan bridge.
#
# A den host (hosts/<m>.nix) composes its aspects into `mainModule`, a plain
# `{ imports = [ ... ]; }` NixOS module. We surface it as a normal flake
# nixosModule so each clan machine config can import it the same way the old
# configs imported `modules.nixosModules.*`. clan remains the builder/deployer.
{ config, ... }:
let
  hosts = config.den.hosts."x86_64-linux";
in
{
  flake.nixosModules.try-den = hosts.try.mainModule;
  flake.nixosModules.abhaile-den = hosts.abhaile.mainModule;
}
