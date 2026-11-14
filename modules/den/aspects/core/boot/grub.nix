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
# The initrd compression mirrors core/systemd/boot.nix. nixpkgs removed the
# scripted initrd, so eachtrach (adopted on one) boots systemd-initrd from its
# next reboot — do that reboot deliberately, Hetzner console at hand.
{
  den.aspects.core.boot.grub = {
    nixos = {
      boot = {
        initrd = {
          compressor = "zstd";
          compressorArgs = [ "-12" ];
        };

        loader.grub = {
          enable = true;
          configurationLimit = 5;
        };
      };
    };
  };
}
