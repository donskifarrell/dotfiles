# modules/den/aspects/services/tailscale.nix
#
# De-clanned tailscale aspect (ported from the old clan service
# services/tailscale/default.nix). Joins the aon tailnet with Tailscale SSH and
# /etc/hosts alias sync.
#
# Three aspects live here, so a host takes only what it needs:
#
#   services.tailscale            the daemon itself. Carries NO secret, so a
#                                 host that is already joined (eachtrach) can
#                                 take it without pulling in sops.
#   services.tailscale.authkey    the shared.yaml auth key + authKeyFile
#                                 wiring. abhaile's; requires secrets.sops.
#   services.tailscale.exit-node  advertise this node as an exit node.
#
# Sub-aspects are NOT implied by their parent — a host lists both (same as
# dev.tools.herdr / dev.tools.herdr.autostart in roles/sandbox.nix).
#
# Auth keys expire (~90d). An already-joined node does not need one to stay
# connected: `tailscaled-autoconnect` exits immediately when the backend state
# is already `Running`, so the key only matters for a fresh join or a re-login.
# The same mechanism is why `extraUpFlags` is NOT the way to change an existing
# node's prefs — see the exit-node aspect below.
{ inputs, ... }:
{
  den.aspects.services.tailscale = {
    nixos =
      {
        pkgs,
        lib,
        ...
      }:
      let
        enableSSH = true;
        enableHostAliases = true;

        # abhaile *uses* an exit node (eachtrach) — a runtime pref, not
        # something this file sets. With an exit node selected, tailscale
        # routes everything that isn't tailnet-local into the tunnel,
        # **including the local LAN**: table 52 gets a default route plus one
        # per locally-connected subnet, at rule priority 5270, above main. The
        # visible symptom is that inbound LAN connections to this host stall —
        # the request arrives on wifi, the reply is routed down tailscale0 and
        # never comes back. That breaks `scoite expose --lan` (TASKS.md S11)
        # and equally any other service abhaile offers its own LAN.
        #
        # --exit-node-allow-lan-access is tailscale's own answer: keep using
        # the exit node for the internet, keep talking to directly-connected
        # subnets directly. It is a no-op when no exit node is selected.
        allowLanWithExitNode = true;
      in
      {
        services.tailscale = {
          enable = true;
          useRoutingFeatures = "both";
          extraUpFlags =
            (lib.optional enableSSH "--ssh")
            ++ (lib.optional allowLanWithExitNode "--exit-node-allow-lan-access");
        };

        networking.firewall = {
          checkReversePath = "loose";
          trustedInterfaces = [ "tailscale0" ];
          allowedUDPPorts = [ 41641 ];
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
    # flake.homeModules.tailscale). This only reaches a user who *includes*
    # `services.tailscale` (df does) — including the aspect on a host applies
    # its nixos side only.
    #
    # The HM module just runs `tailscale systray` as a graphical-session user
    # unit ordered after tray.target; GNOME needs the appindicator extension
    # for a tray at all (services.gnome installs it).
    homeManager = {
      services.tailscale-systray.enable = true;
    };

    # --- authkey ---------------------------------------------------------
    # The aon tailnet auth key, for hosts that may need to (re-)join. Split out
    # of the base aspect 2026-09-04 so that eachtrach — already joined, and
    # internet-facing — can run tailscale without being made a recipient of
    # secrets/shared.yaml (which also holds df's GitHub ssh private keys).
    # A host with its own per-host key sets authKeyFile itself instead; see
    # secrets/eachtrach.nix.
    #
    # Requires the secrets.sops base aspect on the same host.
    authkey.nixos =
      { config, ... }:
      {
        sops.secrets."tailscale-aon_tailnet-authkey" = {
          sopsFile = inputs.self + "/secrets/shared.yaml";
          key = "tailscale/aon_tailnet_authkey";
          mode = "0400";
        };

        services.tailscale.authKeyFile = config.sops.secrets."tailscale-aon_tailnet-authkey".path;
      };

    # --- exit-node -------------------------------------------------------
    # Advertise this node as a tailnet exit node (eachtrach).
    #
    # `extraSetFlags`, not `extraUpFlags`: `tailscale up` only runs via
    # tailscaled-autoconnect, which returns as soon as the backend state is
    # `Running` — so on an already-joined node an extraUpFlags entry would
    # never be applied. extraSetFlags becomes `tailscaled-set.service`, a
    # `tailscale set …` that runs on every activation and is idempotent.
    #
    # NO `networking.nat` here, deliberately. tailscaled does its own exit-node
    # SNAT (NetfilterMode=2): the live eachtrach has a `ts-postrouting` chain
    # with `-m mark --mark 0x40000/0xff0000 -j MASQUERADE` and no nixos-nat
    # service at all. `useRoutingFeatures = "both"` in the base aspect already
    # supplies the other half, the ipv4/ipv6 forwarding sysctls. Adding
    # networking.nat on top would be a second, conflicting NAT implementation —
    # and the old dead code here guessed `eth0`, while this VPS's uplink is
    # `enp1s0`.
    exit-node.nixos = {
      services.tailscale.extraSetFlags = [ "--advertise-exit-node" ];
    };
  };
}
