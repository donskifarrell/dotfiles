# Direct VR video files for Wolvic on Quest; manual start, trusted home LAN only.
{
  den.aspects.services.quest-video.nixos =
    { lib, pkgs, ... }:
    let
      address = "192.168.178.28";
      port = 18083;
      mediaDir = "/home/df/Videos/VR";
    in
    {
      systemd.tmpfiles.rules = [
        "d /home/df/Videos 0700 df users -"
        "d ${mediaDir} 0700 df users -"
      ];

      networking.firewall.interfaces.wlp8s0.allowedTCPPorts = [ port ];

      systemd.services.quest-video = {
        description = "Read-only VR video share for Quest";
        wantedBy = [ ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        serviceConfig = {
          ExecStart = lib.escapeShellArgs [
            (lib.getExe pkgs.miniserve)
            "--interfaces"
            address
            "--port"
            (toString port)
            "--no-symlinks"
            "/srv/quest-video"
          ];
          User = "df";
          Group = "users";
          WorkingDirectory = "/srv/quest-video";
          BindReadOnlyPaths = [ "${mediaDir}:/srv/quest-video" ];
          ProtectHome = "tmpfs";
          ProtectSystem = "strict";
          PrivateTmp = true;
          PrivateDevices = true;
          NoNewPrivileges = true;
          CapabilityBoundingSet = "";
          RestrictSUIDSGID = true;
          RestrictAddressFamilies = [ "AF_INET" ];
          # Trusted tailnet/VM interfaces bypass the host firewall's per-interface rules.
          RestrictNetworkInterfaces = "lo wlp8s0";
          IPAddressDeny = "any";
          IPAddressAllow = "localhost 192.168.178.0/24";
          Restart = "on-failure";
          RestartSec = 5;
          UMask = "0077";
        };
      };
    };
}
