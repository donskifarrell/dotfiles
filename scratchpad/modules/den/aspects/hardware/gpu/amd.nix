# AMD GPU. Ported from modules/system/amdgpu.nix. `opengl.enable` is the
# deprecated alias for `hardware.graphics` so it is dropped here.
{
  den.aspects.hardware.gpu.amd.nixos = _: {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    services.xserver.videoDrivers = [ "amdgpu" ];
  };
}
