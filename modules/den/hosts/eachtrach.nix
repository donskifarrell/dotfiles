# Host `eachtrach` — Hetzner Cloud x86 VPS, the tailnet's exit node.
#
# Adopted into Den **in place** on 2026-09-04: the machine has been running
# since 2025-10-26 from a clan.lol bootstrap and was never reprovisioned, so
# everything below describes a live system rather than a design. Anything that
# looks like an odd override is pinning what the box already does — the
# comments say which. (This supersedes TODO item 2, which assumed a fresh
# nixos-anywhere install of a new VM.)
#
# Headless: no users at all, root by key only. `deploy .#eachtrach` reaches it
# over its PUBLIC ip, not the tailnet name — see modules/flake-parts/deploy.nix.
{ den, inputs, ... }:
let
  # Same key as abhaile's root (df's ~/.ssh/aon.clan). Byte-identical to what
  # /etc/ssh/authorized_keys.d/root already holds on the live box, so adopting
  # the machine does not change who can log in.
  authorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA6h5RafG9hYqgT3nviJO9P9eEUEAHJlIEqFWfoxFOP6";
in
{
  den.hosts.x86_64-linux.eachtrach = {
    # No `users` — nothing interactive runs here, so there is no home-manager
    # closure to build and push over a 2-vCPU link. (roles.server excludes
    # core.home-manager for the same reason.)
    #
    # Adoption dropped the clan-era `mise` account (uid 1000) along with
    # caddy/gh_deployer: declaring no users means NixOS removes the users it
    # used to manage, `mutableUsers = true` notwithstanding — that flag stops
    # NixOS touching *unmanaged* accounts and passwords, it does not preserve
    # ones this config no longer declares. /home/mise (8K, a .bash_history)
    # stays on disk; user removal never deletes a home directory.
  };

  den.aspects.eachtrach = {
    includes = with den.aspects; [
      # Host data wiring (the layout + report themselves are in hosts/eachtrach/).
      hardware.facter
      hardware.storage.disko

      # roles.default with grub swapped in for systemd-boot (BIOS host).
      roles.server

      # sops-nix + eachtrach's own secrets file (NOT shared.yaml).
      secrets.sops
      secrets.eachtrach

      # Tailscale peer + exit node. `services.tailscale.authkey` is
      # deliberately absent: that one reads shared.yaml, and secrets.eachtrach
      # supplies authKeyFile from the per-host file instead.
      services.tailscale
      services.tailscale.exit-node
      # Tailscale SSH off: it intercepted port 22 on the tailnet and gated
      # every login behind the tailnet ACL (df denied, root behind a browser
      # check). Off, `ssh root@eachtrach` is a plain key login over WireGuard.
      services.tailscale.no-ssh
    ];

    nixos =
      { lib, ... }:
      {
        imports = [
          # disko.devices layout for the disk that is already partitioned.
          (inputs.self + "/hosts/eachtrach/disko.nix")
        ];

        facter.reportPath = inputs.self + "/hosts/eachtrach/facter.json";
        nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

        users.users.root.openssh.authorizedKeys.keys = [ authorizedKey ];

        # The machine was installed at 25.11 and its services' state on disk is
        # from that era. core.stateVersion sets 26.11 as a plain definition (for
        # new hosts), so this needs mkForce rather than a plain override.
        system.stateVersion = lib.mkForce "25.11";

        # --- networking: preserve exactly what the live box does -----------
        #
        # eachtrach runs systemd-networkd + resolved with DHCP on enp1s0.
        # Hetzner hands out a /32 address (91.99.168.74) whose default gateway
        # (172.31.1.1) is outside that prefix and only reachable via a DHCP
        # option-121 link-scope route. That works today; re-deriving it — e.g.
        # by falling back to the NixOS default of dhcpcd — is a needless way to
        # lose the box on the next reboot.
        networking.useNetworkd = true;
        services.resolved.enable = true;

        # hardware.facter turns its DHCP module OFF for abhaile's sake (that
        # host drives networking through NetworkManager). eachtrach has no
        # NetworkManager and gets its address from exactly this module, so it
        # must come back on. mkForce because the aspect sets it as a plain
        # definition. Without this the box comes up with no default route.
        facter.detected.dhcp.enable = lib.mkForce true;
      };
  };
}
