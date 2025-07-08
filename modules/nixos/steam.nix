{
  programs = {
    alvr = {
      enable = true;
      openFirewall = true;
    };

    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remoteplay
      dedicatedServer.openFirewall = true; # Open ports in the firewall for steam server

      gamescopeSession.enable = true;
    };

    gamemode.enable = true;
  };
}
