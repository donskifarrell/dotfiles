# GPU-compute diagnostics for the AMD dGPU (RX 9070, RDNA4/gfx1201). Pure
# tooling — no services, no kernel/driver changes (amdgpu + RADV come from
# hardware.gpu.amd / mesa). rocminfo must list `gfx1201` and vulkaninfo must
# show `RADV NAVI48` for GPU inference (services.llm) to be healthy.
#
# Note: /dev/kfd and /dev/dri/renderD* are mode 0666 on NixOS, so no
# video/render group membership is needed for compute, not even for
# DynamicUser systemd services.
{
  den.aspects.hardware.gpu.rocm.nixos =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        rocmPackages.rocminfo # ROCm agent enumeration (gfx target check)
        rocmPackages.rocm-smi # VRAM/clock/power sampling
        amdgpu_top # live per-process GPU/VRAM view
        vulkan-tools # vulkaninfo (RADV device check)
      ];
    };
}
