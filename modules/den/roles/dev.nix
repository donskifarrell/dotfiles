# role-dev — the software-development toolchain for a real host's user:
# languages, git stack, devenv/direnv, and the agent/sandbox tooling (sandvm,
# herdr, omp-auth-broker). A role is just an aspect that `includes` concern
# aspects. (The sandvm guest deliberately does NOT use this role — it carries
# roles.dev-sandbox, a leaner slice.)
{ den, ... }:
{
  den.aspects.roles.dev.includes = with den.aspects; [
    dev.lang.go
    dev.lang.nix
    dev.lang.python

    dev.apps

    dev.git
    dev.git.github
    dev.git.lazygit

    dev.tools.devenv
    dev.tools.direnv
    dev.tools.distrobox
    dev.tools.herdr
    dev.tools.omp-auth-broker
    dev.tools.sandvm
    dev.tools.trippy
  ];
}
