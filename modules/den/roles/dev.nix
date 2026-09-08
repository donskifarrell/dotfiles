# role-dev — the software-development toolchain for a real host's user:
# languages, git stack, devenv/direnv, and the agent/sandbox tooling (scoite,
# herdr).
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
    dev.tools.scoite
    dev.tools.trippy
  ];
}
