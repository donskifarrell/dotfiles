# User `iosta` — the scoite guest user (no real host carries it). Deliberately
# NOT df: it carries none of df's workstation/desktop identity and no key
# material of its own.
#
# Which sandbox tier iosta gets is decided per guest host, not here:
# modules/den/hosts/scoite.nix adds `roles.sandbox.<tier>` to `users.iosta`.
# This aspect is only the parts every tier shares.
{ den, ... }:
let
  # Same public key as modules/den/users/df.nix — it's public, safe to
  # duplicate. It's how df (the only human) ssh'es into a sandbox as iosta.
  authorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA6h5RafG9hYqgT3nviJO9P9eEUEAHJlIEqFWfoxFOP6";
in
{
  den.aspects.iosta = {
    includes = [
      den.batteries.primary-user # isNormalUser + wheel + networkmanager
      (den.batteries.user-shell "fish") # default shell + enable fish at OS/HM
    ];

    nixos = {
      # /workspace is a virtiofs passthrough share — the guest sees the host's
      # real uid/gid on every file. The host-side project owner (df) is uid
      # 1000, so iosta must be too or it cannot write into its own workspace
      # (docs/microvm-sandbox.md, "Why /workspace is virtiofs"). Pinned rather
      # than trusting NixOS's first-normal-user-gets-1000 allocation.
      users.users.iosta.uid = 1000;
      users.users.iosta.openssh.authorizedKeys.keys = [ authorizedKey ];
    };

    # HM uses its own nixpkgs (core/home-manager sets useGlobalPkgs = false),
    # so unfree HM packages need this here, same as df.nix.
    homeManager.nixpkgs.config.allowUnfree = true;
  };
}
