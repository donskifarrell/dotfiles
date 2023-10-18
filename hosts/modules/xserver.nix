{pkgs, ...}: {
  services = {
    xserver = {
      enable = true;
      layout = "us";
      xkbVariant = "";
      libinput.enable = true;
      displayManager.gdm.enable = true;
    };
  };
}
