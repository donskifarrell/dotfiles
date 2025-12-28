{
  config.flake.homeModules.steam = {
    config = {
      programs.steam = {
        enable = true;
        remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remoteplay
        dedicatedServer.openFirewall = true; # Open ports in the firewall for steam server

        gamescopeSession.enable = true;
      };

      gamemode.enable = true;
    };
  };
}
