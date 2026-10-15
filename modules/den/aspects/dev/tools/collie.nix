# Collie (colliepwa.dev) — phone PWA that mirrors herdr panes. Sandbox guests
# only (roles.sandbox.dev). Inert until enabled per guest: `collie start` in the
# guest + `scoite expose --tailnet` on the host. Setup: docs/collie.md.
#
# flake = false + callPackage on our nixpkgs: the upstream derivation only
# wraps the checksummed release tarball, so its pinned nixpkgs buys nothing.
# Bump = `nix flake update collie` (main's sources.json tracks the last release).
{ inputs, ... }:
{
  flake-file.inputs.collie = {
    url = "github:AltanS/collie";
    flake = false;
  };

  den.aspects.dev.tools.collie.homeManager =
    { pkgs, ... }:
    {
      home.packages = [ (pkgs.callPackage "${inputs.collie}/packaging/nix/collie.nix" { }) ];

      # Machine layer; the per-guest tailnet name lives in ~/.config/collie/.env
      # (collie writes that file itself, so it must stay a real file).
      # Bound to SLIRP's fixed guest address, which the host reaches through
      # qemu's hostfwd on the instance's 127.x.y.1; abhaile's `tailscale serve`
      # fronts that (`scoite expose --tailnet`). Not on the bridge address, so
      # other guests have no ordinary route to it; pairing is the real gate.
      home.file.".collie/config.toml".text = ''
        [network]
        host = "10.0.2.15"
        allow_non_loopback_bind = true

        [serve]
        skip_serve = true
      '';
    };
}
