# AMD CPU support. Loads the KVM module so the host can run hardware-accelerated
# guests (libvirt/microvm). Ported from the `boot.kernelModules = [ "kvm-amd" ]`
# line in modules/system/virtualisation.nix — CPU concern split out from libvirt.
{
  den.aspects.hardware.cpu.amd.nixos = _: {
    boot.kernelModules = [ "kvm-amd" ];
    hardware.cpu.amd.updateMicrocode = true;
  };
}
