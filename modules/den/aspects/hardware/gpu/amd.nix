# AMD GPU. Ported from modules/system/amdgpu.nix. `opengl.enable` is the
# deprecated alias for `hardware.graphics` so it is dropped here.
{
  den.aspects.hardware.gpu.amd.nixos = _: {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    # amdgpu.initrd.enable = true;

    services.xserver.videoDrivers = [ "amdgpu" ];

    services.lact.enable = true;

    # ROCm/compute diagnostics live in hardware.gpu.rocm (rocm.nix).
  };
}
