# Host `sandvm` — not a real machine. A single reusable microVM guest shape,
# parameterized per-launch by the `sandvm` CLI (pkgs/by-name/sandvm) via env
# vars (MICROVM_WORKDIR/MICROVM_NAME/...), read impurely by
# `virtualization.microvm-guest`. One project folder = one running instance
# of this same nixosConfiguration; see docs/microvm-sandbox.md.
#
# Deliberately NOT `roles.workstation`/`roles.desktop` at the system level —
# headless, dev-only. `users.df = { }` still pulls df's *full* home-manager
# identity (fish, git, lazygit, even desktop/workstation HM packages) the
# same way it would on a real host: Den only resolves a role's `homeManager`
# keys onto a user, never its `nixos` keys, so this stays lean at the system
# level while df's shell still feels like home. Heavier eval/closure than a
# bare-packages guest is the accepted tradeoff for that.
{
  den,
  lib,
  config,
  ...
}:
{
  den.hosts.x86_64-linux.sandvm = {
    users.df = { };
  };

  den.aspects.sandvm = {
    includes = with den.aspects; [
      roles.default
      roles.dev
      virtualization.microvm-guest
    ];

    nixos = { lib, ... }: {
      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
  };

  perSystem =
    { system, ... }:
    lib.mkIf (system == "x86_64-linux") {
      packages.sandvm-guest = config.flake.nixosConfigurations.sandvm.config.microvm.declaredRunner;
    };
}
