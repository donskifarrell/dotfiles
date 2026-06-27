{
  den.aspects.core.security = {
    nixos = _: {
      security.polkit.enable = true;

      security = {
        sudo.enable = false;
        sudo-rs = {
          enable = true;
          execWheelOnly = true;
          wheelNeedsPassword = false;
        };
      };
    };
  };
}
