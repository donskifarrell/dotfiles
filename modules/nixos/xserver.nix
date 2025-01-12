{
  services = {
    xserver = {
      enable = true;

      xkb = {
        layout = "us";
        variant = "";
      };
    };

    libinput.enable = true;
  };
}
