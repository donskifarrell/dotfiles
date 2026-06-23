# Ported from modules/home/steam.nix. steam + gamemode are NixOS-level options
# (the legacy repo filed them under home modules, but they configure the system),
# so this aspect is a `nixos` block.
{
  den.aspects.apps.gaming.steam.nixos = _: {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remoteplay
      dedicatedServer.openFirewall = true; # Open ports in the firewall for steam server

      gamescopeSession.enable = true;
    };

    programs.gamemode.enable = true;
  };
}
