# A role is just an aspect that `includes` concern aspects.
# This is the thin `role-server` from the plan's taxonomy — the minimal
# set to boot a headless server. Grow it by adding more `core.*` / `services.*`.
{ den, ... }:
{
  den.aspects.roles.dev.includes = with den.aspects; [
    dev.lang.go
    dev.lang.nix
    dev.lang.python

    dev.apps

    dev.tools.devenv
    dev.tools.direnv
    dev.tools.distrobox
    dev.tools.trippy
  ];
}
