# A role is just an aspect that `includes` concern aspects.
# This is the thin `role-server` from the plan's taxonomy — the minimal
# set to boot a headless server. Grow it by adding more `core.*` / `services.*`.
{ den, ... }:
{
  den.aspects.roles.server.includes = with den.aspects; [
    core.nix
    core.i18n
    core.openssh
    core.networking
    core.shell
    core.vm-login # test-only; affects build-vm only, not real deploys
  ];
}
