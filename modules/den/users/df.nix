# User `df` — one file: the user aspect (auto-applied to user `df`).
{ den, ... }:
let
  authorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA6h5RafG9hYqgT3nviJO9P9eEUEAHJlIEqFWfoxFOP6";
in
{
  den.aspects.df = with den.aspects; {
    includes = [
      den.batteries.primary-user # isNormalUser + wheel + networkmanager
      (den.batteries.user-shell "fish") # default shell + enable fish at OS/HM

      # df gets its home apps by including the same roles the host composes.
      # We deliberately do NOT use `den.batteries.host-aspects` here: its
      # host->user homeManager projection is a fleet-level step that only runs
      # during den's full `instantiate`, which our clan bridge (intoAttr=[] +
      # mainModule, see modules/den/bridge.nix) skips. Including the roles on
      # the user resolves their `homeManager` keys onto df through the path the
      # bridge DOES capture — den ignores the roles' `nixos` keys for a user, so
      # there's no duplication and apps stay defined once in the roles.
      roles.workstation
      roles.dev
      roles.desktop

      # Forward the host's (and its included roles') homeManager aspects onto
      # df. Without this, role/host-scoped home apps — fish config, git, the dev
      # tooling, the desktop graphical apps, etc. — never reach df's
      # home-manager; only df's own homeManager block, user-scoped includes
      # (e.g. <host>.df.includes), and the user-shell battery would apply.
      # den.batteries.host-aspects
    ];

    # df's NixOS-side config on every host it lives on.
    nixos = {
      users.users.df.openssh.authorizedKeys.keys = [ authorizedKey ];
    };

    # HM uses its own nixpkgs (core/home-manager sets useGlobalPkgs = false), so
    # allowUnfree must be set here for df's graphical apps (1password, slack, …).
    homeManager.nixpkgs.config.allowUnfree = true;
  };
}
