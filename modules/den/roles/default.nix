# role-default — the true minimal base every host/guest composes: locale, nix,
# sshd, systemd, shell basics. Deliberately NO desktop networking here:
# NetworkManager + avahi moved to roles.workstation (2026-07-14) — a sandvm
# microVM guest behind SLIRP and a headless VPS both want systemd-networkd
# DHCP (or their own wiring), not a desktop network daemon + open-firewall
# mDNS. core.systemd.boot (systemd-boot, UEFI-only) is still here because
# every *current* consumer wants it; a BIOS-boot host (Hetzner Cloud x86
# eachtrach) will need to exclude/override it — see TODO.md item 2.
{ den, ... }:
{
  den.aspects.roles.default = {
    includes = with den.aspects; [
      core.disable-docs
      core.home-manager
      core.locale
      core.network.openssh
      core.nix
      core.nix.nh
      core.nix.nixpkgs
      core.security
      core.stateVersion
      core.systemd
      core.systemd.boot

      shell
      shell.bundles.base
    ];
  };
}
