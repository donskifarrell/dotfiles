{
  services = {
    openssh = {
      enable = true;
      settings = {
        # Forbid root login through SSH.
        PermitRootLogin = "no";
      };
    };
  };

  programs.ssh = {
    startAgent = true;
  };
}
