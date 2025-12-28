{
  config.flake.nixosModules.amdgpu = _: {
    config = {
      hardware = {
        graphics = {
          enable = true;
          enable32Bit = true;
        };

        opengl.enable = true;

        # amdgpu.initrd.enable = true;
      };

      services.xserver.videoDrivers = [ "amdgpu" ];
    };
  };
}
