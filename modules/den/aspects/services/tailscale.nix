# modules/den/aspects/services/tailscale.nix
#
# De-clanned tailscale aspect (ported from the old clan service
# services/tailscale/default.nix). abhaile joins the aon tailnet as a plain peer
# with Tailscale SSH and /etc/hosts alias sync; it is NOT an exit node.
#
# The auth key comes from sops (declared in aspects/secrets/sops.nix as
# "tailscale-aon_tailnet-authkey"), so including this aspect requires secrets.sops
# to be included on the same host. Auth keys expire (~90d): for an already-joined
# node it isn't needed to stay connected; mint a fresh one and
# `sops secrets/shared.yaml` for new joins.
{
  den.aspects.services.tailscale = {
    nixos =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      let
        enableSSH = true;
        exitNode = false;
        enableHostAliases = true;
      in
      {
        services.tailscale = {
          enable = true;
          useRoutingFeatures = "both";
          authKeyFile = config.sops.secrets."tailscale-aon_tailnet-authkey".path;
          extraUpFlags = (lib.optional enableSSH "--ssh") ++ (lib.optional exitNode "--advertise-exit-node");
        };

        networking.firewall = {
          checkReversePath = "loose";
          trustedInterfaces = [ "tailscale0" ];
          allowedUDPPorts = [ 41641 ];
        };

        # NAT for exit nodes (no-op while exitNode = false).
        networking.nat = lib.mkIf exitNode {
          enable = true;
          externalInterface = lib.mkDefault (if config.networking.interfaces ? "eth0" then "eth0" else "");
          internalInterfaces = [ "tailscale0" ];
        };

        environment.systemPackages = [ pkgs.tailscale ];

        # Sync Tailscale device names into /etc/hosts (inlined from the old
        # services/tailscale/host-sync.nix). Gated on enableHostAliases.
        systemd.services.tailscale-host-sync = lib.mkIf enableHostAliases {
          description = "Sync Tailscale hostnames to /etc/hosts";
          after = [ "tailscaled.service" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = pkgs.writeShellScript "tailscale-host-sync" ''
              ${pkgs.tailscale}/bin/tailscale status --json &>/dev/null || exit 0

              TEMP=$(mktemp)
              trap 'rm -f $TEMP' EXIT

              ${pkgs.tailscale}/bin/tailscale status --json | \
                ${pkgs.jq}/bin/jq -r '.Peer[] | select(.DNSName and .DNSName != "") | .DNSName as $dns | select($dns | split(".")[0] != "" and ($dns | split(".")[0] != null)) | "\(.TailscaleIPs[0]) \($dns | split(".")[0])"' | \
                grep -v " null$" | \
                sort > "$TEMP"

              OLD_CONTENT=$(${pkgs.gnused}/bin/sed -n '/# TAILSCALE-ALIASES-START/,/# TAILSCALE-ALIASES-END/p' /etc/hosts 2>/dev/null | \
                ${pkgs.gnused}/bin/sed '1d;$d' | sort)
              NEW_CONTENT=$(cat "$TEMP")

              if [ "$OLD_CONTENT" != "$NEW_CONTENT" ]; then
                ${pkgs.gnused}/bin/sed '/# TAILSCALE-ALIASES-START/,/# TAILSCALE-ALIASES-END/d' /etc/hosts > /etc/hosts.new

                if [ -s "$TEMP" ]; then
                  echo "# TAILSCALE-ALIASES-START" >> /etc/hosts.new
                  cat "$TEMP" >> /etc/hosts.new
                  echo "# TAILSCALE-ALIASES-END" >> /etc/hosts.new
                fi

                ${pkgs.coreutils}/bin/mv -f /etc/hosts.new /etc/hosts
              fi
            '';
          };
        };

        systemd.timers.tailscale-host-sync = lib.mkIf enableHostAliases {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "1min";
            OnUnitActiveSec = "1min";
          };
        };
      };

    # Tailscale tray applet for df's desktop session (parity with the old
    # flake.homeModules.tailscale).
    homeManager = {
      services.tailscale-systray.enable = true;
    };
  };
}
