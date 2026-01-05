{
  config.flake.nixosModules.nix-virt =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.secretsUser;
      nixvirt = pkgs.nixvirt;
    in
    {
      config = {
        virtualisation.libvirt.connections."qemu:///system" = {
          networks = [
            {
              definition = nixvirt.lib.network.writeXML (
                nixvirt.lib.network.templates.nat {
                  name = "clan-nat";
                  subnet = "192.168.100.0/24";
                }
              );
              active = true;
            }
          ];

          pools = [
            {
              definition = nixvirt.lib.pool.writeXML (
                nixvirt.lib.pool.templates.dir {
                  name = "clan-vms";
                  path = "/var/lib/libvirt/clan-vms";
                }
              );
              active = true;
            }
          ];

          domains = [
            {
              definition = nixvirt.lib.domain.writeXML (
                nixvirt.lib.domain.templates.nixos {
                  name = "vm-bb";
                  memory = 4096;
                  vcpu = 4;

                  volume = {
                    pool = "clan-vms";
                    size = 40 * 1024;
                  };

                  network = {
                    network = "clan-nat";
                    model = "virtio";
                  };

                  nixosConfig = config.clan.machines."vm-bb".nixosConfiguration;
                }
              );

              active = true;
              autostart = true;
            }
          ];
        };
      };
    };
}
