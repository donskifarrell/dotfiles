# Hosts `sandvm-{minimal,generic,devenv,workstation}` — not real machines. Four
# reusable microVM guest shapes, one per sandbox tier (modules/den/roles/
# sandbox.nix); the `sandvm` CLI's `--type` picks which one a launch boots.
#
# They share everything except that tier role: the same base (`roles.default`),
# the same guest plumbing (`virtualization.microvm-guest`) and the same guest
# user, `iosta` (modules/den/users/iosta.nix) — a sandbox-only account with
# none of df's identity, uid-pinned to 1000 so the virtiofs `/workspace`
# passthrough lands on the host-side owner.
#
# Both the host and its user get the tier role, because Den resolves an
# entity's `aspect` for its own class only: the host's aspect supplies the
# role's `nixos` keys, the user's aspect its `homeManager` keys. (Entities
# take a single `aspect` *value* — a free-form `includes` on the entity itself
# is silently ignored, which is why these are composed inline here rather than
# added to `den.hosts.….includes`.)
#
# Per-instance settings (workdir, ports, cpu/mem, disk sizes, credentials) are
# NOT here — they reach qemu through the runner script only, so all instances
# of a tier share one built system closure. See docs/microvm-sandbox.md.
{
  den,
  lib,
  config,
  ...
}:
let
  tiers = {
    minimal = den.aspects.roles.sandbox.minimal;
    generic = den.aspects.roles.sandbox.generic;
    devenv = den.aspects.roles.sandbox.devenv;
    workstation = den.aspects.roles.sandbox.workstation;
  };

  hostName = tier: "sandvm-${tier}";

  # The guest shape every tier shares. An inline aspect value, same as the
  # ones `den.batteries.*` return — `includes` and `aspect` both take values,
  # not names.
  guestBase = {
    includes = with den.aspects; [
      roles.default
      virtualization.microvm-guest
    ];

    nixos =
      { lib, ... }:
      {
        nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      };
  };
in
{
  den.hosts.x86_64-linux = lib.mapAttrs' (
    tier: role:
    lib.nameValuePair (hostName tier) {
      aspect.includes = [
        guestBase
        role
      ];
      users.iosta.aspect.includes = [
        den.aspects.iosta
        role
      ];
    }
  ) tiers;

  perSystem =
    { system, ... }:
    lib.mkIf (system == "x86_64-linux") {
      packages = lib.mapAttrs' (
        tier: _:
        lib.nameValuePair "sandvm-guest-${tier}"
          config.flake.nixosConfigurations.${hostName tier}.config.microvm.declaredRunner
      ) tiers;
    };
}
