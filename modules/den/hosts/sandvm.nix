# Host `sandvm` — not a real machine. A single reusable microVM guest shape,
# parameterized per-launch by the `sandvm` CLI (pkgs/by-name/sandvm) via env
# vars (MICROVM_WORKDIR/MICROVM_NAME/...), read impurely by
# `virtualization.microvm-guest`. One project folder = one running instance
# of this same nixosConfiguration; see docs/microvm-sandbox.md.
#
# Deliberately headless and dev-only: the guest user is `iosta`
# (modules/den/users/iosta.nix), which carries only `roles.dev-sandbox` — the
# TUI slice of the dev environment (shell config, git, devenv/direnv, herdr,
# agent tools) with none of df's workstation/desktop identity. The same role
# sits in the system-level includes below for its `nixos`/`os` keys; Den only
# resolves a role's `homeManager` keys onto a user, so nothing is duplicated.
{
  den,
  lib,
  config,
  ...
}:
{
  den.hosts.x86_64-linux.sandvm = {
    users.iosta = { };
  };

  den.aspects.sandvm = {
    includes = with den.aspects; [
      roles.default
      roles.dev-sandbox
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
