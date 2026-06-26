# den → clan bridge.
#
# A den host (hosts/try.nix) composes its aspects into `mainModule`, a plain
# `{ imports = [ ... ]; }` NixOS module. We surface it as a normal flake
# nixosModule so clan's machine config can import it the same way abhaile
# imports `modules.nixosModules.*`. clan remains the system builder/deployer.
{ config, ... }:
{
  flake.nixosModules.try-den = config.den.hosts."x86_64-linux".try.mainModule;
}
