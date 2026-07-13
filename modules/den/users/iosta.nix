# User `iosta` — the sandvm guest user (no real host carries it). Deliberately
# NOT df: it includes only `roles.dev-sandbox` — the headless TUI dev
# environment — instead of df's full workstation/desktop identity, so a guest's
# eval/closure stays lean and no workstation-only config leaks into sandboxes.
{ den, ... }:
let
  # Same public key as modules/den/users/df.nix — it's public, safe to
  # duplicate. It's how df (the only human) ssh'es into a sandbox as iosta;
  # iosta has no key material of its own (see docs/microvm-sandbox.md,
  # "what's deliberately NOT shared").
  authorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA6h5RafG9hYqgT3nviJO9P9eEUEAHJlIEqFWfoxFOP6";
in
{
  den.aspects.iosta = with den.aspects; {
    includes = [
      den.batteries.primary-user # isNormalUser + wheel + networkmanager
      (den.batteries.user-shell "fish") # default shell + enable fish at OS/HM

      # The whole point of iosta: only the sandbox role. See the role file for
      # what that includes (and pointedly does not).
      roles.dev-sandbox
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
    # so unfree HM packages need this here, same as df.nix. Nothing in
    # dev-sandbox is unfree today; kept so adding one later doesn't break eval.
    homeManager.nixpkgs.config.allowUnfree = true;
  };
}
