# Read-only WebDAV (native player) + password SMB (DeoVR) of one folder; manual start, home LAN only.
# `systemctl start|stop quest-video` drives both. DLNA rejected: no auth, SSDP-announced LAN-wide.
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

      networking.firewall.interfaces.wlp8s0.allowedTCPPorts = [
        port
        445
      ];

      # Login = df + separate Samba password (`sudo smbpasswd -a df`, kept in /var/lib/samba).
      # No nmbd/wsdd/winbind: nothing announced; clients connect by IP.
      services.samba = {
        enable = true;
        nmbd.enable = false;
        winbindd.enable = false;
        settings = {
          global = {
            "bind interfaces only" = "yes";
            interfaces = "127.0.0.1 ${address}";
            "hosts allow" = "127.0.0.1 192.168.178.0/24";
            "smb ports" = "445";
            "disable netbios" = "yes";
            "map to guest" = "Never";
            "restrict anonymous" = "2";
            "load printers" = "no";
            printing = "bsd";
            "printcap name" = "/dev/null";
            "disable spoolss" = "yes";
          };
          quest = {
            path = "/srv/quest-video";
            "read only" = "yes";
            "guest ok" = "no";
            "valid users" = "df";
            "follow symlinks" = "no";
            "veto files" = "/.*/";
          };
        };
      };
      systemd.targets.samba.wantedBy = lib.mkForce [ ];
      systemd.services.samba-smbd = {
        partOf = [ "quest-video.service" ];
        serviceConfig = {
          # Same read-only view as miniserve, enforced by the mount even if smb.conf is wrong.
          BindReadOnlyPaths = [ "${mediaDir}:/srv/quest-video" ];
          ProtectHome = "tmpfs";
          RestrictNetworkInterfaces = "lo wlp8s0";
          IPAddressDeny = "any";
          IPAddressAllow = "localhost 192.168.178.0/24";
        };
      };

      systemd.services.quest-video = {
        description = "Read-only VR video share for Quest";
        wantedBy = [ ];
        wants = [
          "network-online.target"
          "samba-smbd.service"
        ];
        after = [ "network-online.target" ];
        serviceConfig = {
          ExecStart = lib.escapeShellArgs [
            (lib.getExe pkgs.miniserve)
            "--interfaces"
            address
            "--port"
            (toString port)
            "--no-symlinks"
            "--enable-webdav"
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
