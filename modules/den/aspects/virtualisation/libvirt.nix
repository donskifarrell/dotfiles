# Ported from modules/system/virtualisation.nix. libvirtd + QEMU/KVM with swtpm
# (TPM 2.0 for Windows guests) and SPICE USB redirection.
#
# Two things from the legacy module moved elsewhere:
#   - `boot.kernelModules = [ "kvm-amd" ]` -> hardware.cpu.amd
#   - adding the primary user to the `libvirtd`/`kvm` groups -> the user aspect
#     (df.nix) or the role that includes this, since Den owns user identity.
{
  den.aspects.virtualization.libvirt.nixos =
    { pkgs, ... }:
    {
      virtualisation.libvirtd = {
        enable = true;
        qemu = {
          package = pkgs.qemu_kvm;
          runAsRoot = false;

          # To run Windows VMs with TPM 2.0 via libvirt
          swtpm.enable = true;
        };
      };

      # Enable USB redirection (optional)
      virtualisation.spiceUSBRedirection.enable = true;

      # For virt-manager, helps avoid password pain
      security.polkit.enable = true;

      networking.firewall = {
        enable = true;
        trustedInterfaces = [ "virbr0" ];
      };

      environment.systemPackages = with pkgs; [
        dnsmasq
        qemu_kvm
        quickemu
        virt-manager
      ];

      # boot.kernelModules = [ "kvm-amd" ];
      # users.users.${cfg.user}.extraGroups = [
      #   "libvirtd"
      #   "kvm"
      # ];
    };
}
