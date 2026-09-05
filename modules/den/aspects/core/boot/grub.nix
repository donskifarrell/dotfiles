# core.boot.grub — the BIOS/grub counterpart to `core.systemd.boot`.
#
# `core.systemd.boot` is systemd-boot, which is UEFI-only. A legacy-BIOS host
# (Hetzner Cloud x86 — eachtrach) needs grub instead, so it takes this aspect
# and excludes that one; `roles.server` does exactly that swap.
#
# Deliberately absent: `boot.loader.efi.*`. The grub module asserts that
# `efiInstallAsRemovable` and `boot.loader.efi.canTouchEfiVariables` are never
# both set, and the host's disko file (hosts/eachtrach/disko.nix, generated
# against the installed disk) sets the former. `core.systemd.boot` sets the
# latter — bringing both in is an eval failure, not a silent misconfiguration,
# but it is the trap worth naming.
#
# Also absent: `boot.loader.grub.devices`. disko derives it from the layout's
# EF02 partition, so it stays host data.
#
# The initrd compression mirrors core/systemd/boot.nix. `initrd.systemd.enable`
# does NOT: this nixpkgs (26.11-pre, FlakeHub weekly) defaults it to `true`,
# but eachtrach was adopted running a scripted initrd, so leaving the default
# in place would silently fold an initrd-implementation switch into the first
# reboot after adoption — alongside a new kernel, a regenerated grub config and
# a networkd config from a different nixpkgs. On a VPS whose only recovery path
# is Hetzner's web console, that is the wrong number of variables to change at
# once. Flip it (and reboot deliberately) as its own step; abhaile has run
# systemd-initrd happily for months, so this is caution, not a known problem.
{
  den.aspects.core.boot.grub = {
    nixos = {
      boot = {
        initrd = {
          compressor = "zstd";
          compressorArgs = [ "-12" ];
          systemd.enable = false;
        };

        loader.grub = {
          enable = true;
          configurationLimit = 5;
        };
      };
    };
  };
}
