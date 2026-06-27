# ---
# schema = "single-disk-custom-luks"
# [placeholders]
# mainDisk = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_1TB_S6Z1NJ0W231781Y"
# ---
# CHANGING this configuration requires wiping and reinstalling the machine
{

  # Bootloader is now den's core/systemd/boot aspect (systemd-boot), pulled in
  # via abhaile-den. The old grub lines were removed for the den migration; the
  # EF02 "boot" partition below is now unused but kept (removing it would change
  # the layout and require a wipe). systemd-boot installs to the ESP (/boot).
  disko.devices = {
    disk = {
      main = {
        name = "main-4d57d29882274da888540eec25a1f017";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_1TB_S6Z1NJ0W231781Y";
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
                type = "luks";
                name = "cryptroot"; # maps to /dev/mapper/cryptroot

                # optional but common on SSDs:
                settings = {
                  allowDiscards = true;
                };

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
  };
}
