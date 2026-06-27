# den → clan bridge (try only).
#
# `try` is still clan-built: den composes its aspects into `mainModule` and we
# surface that as a flake nixosModule so machines/try/configuration.nix can
# import it. abhaile is no longer here — Den emits nixosConfigurations.abhaile
# directly (see hosts/abhaile.nix), so it needs no bridge.
{ config, ... }:
let
  hosts = config.den.hosts."x86_64-linux";
in
{
  flake.nixosModules.try-den = hosts.try.mainModule;
}
