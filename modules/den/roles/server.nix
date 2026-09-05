# role-server — a headless machine with no interactive user: `roles.default`
# with the bootloader swapped from systemd-boot (UEFI) to grub (legacy BIOS).
#
# Introduced 2026-09-04 for eachtrach, the Hetzner Cloud x86 VPS. Hetzner's x86
# instances boot legacy BIOS, so `core.systemd.boot` would both fail to install
# and (via `boot.loader.efi.canTouchEfiVariables`) trip the grub module's
# assertion against the host's `efiInstallAsRemovable`. `excludes` drops it out
# of roles.default's include tree; `core.boot.grub` takes its place.
#
# Deliberately does NOT touch networking. The obvious addition would be
# systemd-networkd DHCP (TODO item 2 suggested it), but eachtrach was adopted
# in place from a running clan install and already has a working Hetzner
# network setup — a /32 address with an off-subnet gateway, which is exactly
# the shape that is easy to re-derive wrongly. The host file pins what the live
# box does (`networking.useNetworkd`) rather than this role imposing a policy.
{ den, ... }:
{
  den.aspects.roles.server = {
    includes = with den.aspects; [
      roles.default
      core.boot.grub
    ];

    excludes = with den.aspects; [
      core.systemd.boot

      # A server declares no users, so Den's home-manager battery never
      # imports the home-manager NixOS module — and core.home-manager's
      # `home-manager.*` settings then fail to evaluate against an option that
      # does not exist. Nothing here has a home to manage anyway.
      core.home-manager
    ];
  };
}
