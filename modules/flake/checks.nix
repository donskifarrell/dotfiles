# Per-host `system.build.toplevel` as flake checks, so `nix flake check` actually
# builds every NixOS config Den emits.
#
# This is wired at the flake (top) level on purpose: `config.flake.nixosConfigurations`
# is only reachable here, NOT inside `perSystem`. The previous attempt lived in
# `perSystem` with a `config.flake.nixosConfigurations or { }` fallback, which
# silently resolved to `{ }` — so the per-host builds never ran.
{ lib, config, ... }:
let
  configs = config.flake.nixosConfigurations;
  systemOf = name: configs.${name}.config.nixpkgs.hostPlatform.system;
  hostsBySystem = lib.groupBy systemOf (lib.attrNames configs);
in
{
  flake.checks = lib.mapAttrs (
    _system: names: lib.genAttrs names (name: configs.${name}.config.system.build.toplevel)
  ) hostsBySystem;
}
