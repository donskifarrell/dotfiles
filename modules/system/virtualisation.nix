# Note: for first time install, run:
#
#   virsh -c qemu:///system net-list --all
#
# If default exists but inactive:
#
#   sudo virsh net-start default
#   sudo virsh net-autostart default
#
{
  config.flake.nixosModules.virtualisation =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.secretsUser;
    in
    {
      config = {
        boot.kernelModules = [ "kvm-amd" ];

        virtualisation.libvirtd = {
          enable = true;
          # verbose = true;

          qemu = {
            package = pkgs.qemu_kvm;
            runAsRoot = false;

            # To run Windows VMs with TPM 2.0 via libvirt
            swtpm.enable = true;
          };

        };

        # Enable USB redirection (optional)
        virtualisation.spiceUSBRedirection.enable = true;

        # Useful tooling (optional)
        environment.systemPackages = with pkgs; [
          dnsmasq
          qemu_kvm
          quickemu
          virt-manager
        ];

        users.users.${cfg.user}.extraGroups = [
          "libvirtd"
          "kvm"
        ];

        # For virt-manager, helps avoid password pain
        security.polkit.enable = true;
      };
    };
}
