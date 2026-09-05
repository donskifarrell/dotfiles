# eachtrach disk layout — Hetzner Cloud x86 VPS.
#
# Provenance: recovered verbatim from the clan era
# (`git show 220c93e^:machines/eachtrach/disko.nix`) when the running machine
# was adopted into Den in place, 2026-09-04. It is NOT a fresh design — it
# describes the partitioning that is already on the disk, verified against the
# live box:
#
#   sda  38.1G   scsi-0QEMU_QEMU_HARDDISK_105596894
#   ├─sda1  1M           EF02 bios_boot (grub's MBR gap on GPT)
#   ├─sda2  500M vfat    /boot
#   └─sda3  37.7G ext4   /
#
# CHANGING this file requires wiping and reinstalling the machine.
#
# Hetzner Cloud x86 instances boot **legacy BIOS** (/sys/firmware/efi is absent
# on the live box), which is why this is grub + an EF02 partition rather than
# systemd-boot — see modules/den/roles/server.nix. `boot.loader.grub.devices`
# is not set here on purpose: disko's gpt type sets it from the EF02 partition
# (disko lib/types/gpt.nix). `efiInstallAsRemovable` and
# `boot.loader.efi.canTouchEfiVariables` are mutually exclusive per the grub
# module's own assertion — that is the other reason `core.systemd.boot` (which
# sets canTouchEfiVariables) must not reach this host.
{
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = true;
  boot.loader.grub.enable = true;
  disko.devices = {
    disk = {
      main = {
        name = "main-ea13e8f4c5be4aef901759b10305bab7";
        device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_105596894";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            "boot" = {
              size = "1M";
              type = "EF02"; # for grub MBR
              priority = 1;
            };
            ESP = {
              type = "EF00";
              size = "500M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
