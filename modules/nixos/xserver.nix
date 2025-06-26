{
  services = {
    xserver = {
      enable = true;

      videoDrivers = [ "amdgpu" ];

      xkb = {
        layout = "us";
        variant = "";
      };
    };

    libinput.enable = true;
  };
}
