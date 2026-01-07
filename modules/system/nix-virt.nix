{ inputs, ... }:
{
  config.flake.nixosModules.nix-virt =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.secretsUser;
    in
    {
      imports = [
        inputs.NixVirt.nixosModules.default
      ];

      config = {
        virtualisation = {

          libvirt = {
            enable = true;
            verbose = true;
            swtpm.enable = true;
          };

          # Enable SPICE USB redirection if requested
          # spiceUSBRedirection.enable = cfg.spiceUSBRedirection;

          libvirt.connections."qemu:///system" = {
            networks = [
              {
                definition = inputs.NixVirt.lib.network.writeXML (
                  inputs.NixVirt.lib.network.templates.nat {
                    name = "clan-nat";
                    subnet = "192.168.100.0/24";
                  }
                );
                active = true;
              }
            ];

            pools = [
              {
                definition = inputs.NixVirt.lib.pool.writeXML (
                  inputs.NixVirt.lib.pool.templates.dir {
                    name = "clan-vms";
                    path = "/var/lib/libvirt/clan-vms";
                  }
                );
                active = true;
              }
            ];

            domains = [
              {
                definition = inputs.NixVirt.lib.domain.writeXML (
                  inputs.NixVirt.lib.domain.templates.linux {
                    name = "vm-bb";
                    uuid = "cc7439ed-36af-4696-a6f2-1f0c4474d87e"; # random

                    memory = {
                      count = 4;
                      unit = "GiB";
                    };

                    # Disk: reference a QCOW2 volume by pool+volume name
                    # storage_vol = {
                    #   pool = "clan-vms";
                    #   volume = "vm-bb.qcow2";
                    # };

                    # Optional base image backing store (set to null if not used)
                    backing_vol = null;

                    # ISO inserted as CDROM for installation
                    # install_vol = installIsoPath;

                    # Connect to the bridge created by the NAT network above
                    # bridge_name = "virbr100";

                    virtio_video = true;
                    virtio_drive = true;

                    # memory = 4096;
                    # vcpu = 4;

                    # volume = {
                    #   pool = "clan-vms";
                    #   size = 40 * 1024;
                    # };

                    # network = {
                    #   network = "clan-nat";
                    #   model = "virtio";
                    # };

                    nixosConfig = config.clan.machines."vm-bb".nixosConfiguration;
                  }
                );

                active = true;
              }
            ];
          };
        };
      };
    };
}
