# User `df` — one file: the user aspect (auto-applied to user `df`).
{ den, ... }:
let
  authorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA6h5RafG9hYqgT3nviJO9P9eEUEAHJlIEqFWfoxFOP6";
in
{
  den.aspects.df = {
    includes = [
      den.batteries.primary-user # isNormalUser + wheel + networkmanager
      (den.batteries.user-shell "fish") # default shell + enable fish at OS/HM

      # Forward the host's (and its included roles') homeManager aspects onto
      # df. Without this, role/host-scoped home apps — fish config, git, the dev
      # tooling, the desktop graphical apps, etc. — never reach df's
      # home-manager; only df's own homeManager block, user-scoped includes
      # (e.g. <host>.df.includes), and the user-shell battery would apply.
      den.batteries.host-aspects
    ];

    # df's NixOS-side config on every host it lives on.
    nixos = {
      users.users.df.openssh.authorizedKeys.keys = [ authorizedKey ];
    };
  };
}
