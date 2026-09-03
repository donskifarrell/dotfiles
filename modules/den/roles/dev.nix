# role-dev — the software-development toolchain for a real host's user:
# languages, git stack, devenv/direnv, and the agent/sandbox tooling (scoite,
# omp-auth-broker). herdr was dropped 2026-08-26 (df) — see dev/tools/herdr.nix.
# A role is just an aspect that `includes` concern aspects. (The scoite guest
# deliberately does NOT use this role — it carries the roles.sandbox.* tiers,
# leaner slices.)
{ den, ... }:
{
  den.aspects.roles.dev.includes = with den.aspects; [
    dev.lang.go
    dev.lang.nix
    dev.lang.node
    dev.lang.python

    dev.apps

    dev.git
    dev.git.github
    dev.git.lazygit

    dev.tools.cc
    dev.tools.devenv
    dev.tools.direnv
    dev.tools.distrobox
    dev.tools.herdr
    dev.tools.omp-auth-broker
    dev.tools.scoite
    dev.tools.trippy
  ];
}
