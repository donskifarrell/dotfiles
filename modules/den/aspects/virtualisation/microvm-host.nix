# Host-side support for `scoite` (per-project sandboxed microVMs for coding
# agents — see modules/den/hosts/scoite.nix + docs/microvm-sandbox.md).
#
# scoite VMs run *imperatively* (build the guest's `config.microvm.declaredRunner`
# and exec it directly), not through microvm.nix's systemd-managed
# `microvm.host`/`microvm.vms.*` path — so no `microvm.nixosModules.host`
# import is needed here. All this host needs is somewhere persistent for the
# guest's SSH host key to live (so it survives the guest's ephemeral rootfs
# across runs and `known_hosts`/VSCode Remote-SSH never see a changed
# identity), generated once up front to dodge a first-boot race between
# concurrent scoite instances.
#
# Networking (2026-08-25, TASKS.md S8): guests get a *second* NIC on the
# host-managed bridge `scoitebr0` (10.77.0.0/24, DHCP from a dnsmasq of its
# own). Their first NIC stays qemu SLIRP, which keeps being the default route
# and the path to abhaile's loopback services at 10.0.2.2 (llama-server :8080,
# the omp auth-broker :8765, harmonia :5000). The bridge exists so a guest has
# a real address the host can reach *inbound* without a qemu forward — which
# is what makes `scoite-<name>.local` (mDNS, S9) and LAN exposure (S11)
# possible at all.
{
  den.aspects.virtualization.microvm-host.nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      bridge = "scoitebr0";
      # Deliberately not 192.168.122.0/24 (libvirt's virbr0 — and a subnet
      # tailscale has been seen to hijack on this host), not the LAN's
      # 192.168.178.0/24, not 10.0.2.0/24 (qemu SLIRP), not 100.64/10
      # (tailscale CGNAT).
      hostIp = "10.77.0.1";
      prefix = 24;
      subnet = "10.77.0.0/24";
      # Below tailscale's 5270 ("from all lookup 52") and above nothing else
      # that matters — see the ip rule in scoite-bridge.service.
      rulePriority = 5000;
      dhcpFrom = "10.77.0.100";
      dhcpTo = "10.77.0.240";

      # `scoite expose --lan` (TASKS.md S11) is the only thing that ever
      # reaches off this machine, and it needs root. Rather than give the CLI
      # privileges, root gets this one small, auditable verb. df has
      # passwordless sudo (core.security), so the CLI just calls
      # `sudo scoite-lan ...`.
      #
      # iptables, not nft: abhaile's firewall, libvirt and tailscale are all
      # in the iptables world (`nft list ruleset` is empty here), and one
      # backend beats two.
      scoite-lan = pkgs.writeShellApplication {
        name = "scoite-lan";
        runtimeInputs = [
          pkgs.iptables
          pkgs.iproute2
        ];
        text = ''
          CHAIN_PRE=SCOITE_LAN
          CHAIN_POST=SCOITE_LAN_POST
          SUBNET=${subnet}
          BRIDGE=${bridge}

          die() { echo "scoite-lan: $*" >&2; exit 1; }

          # Idempotent: create the chains and hook them once.
          init() {
            iptables -t nat -n --list "$CHAIN_PRE" >/dev/null 2>&1 \
              || iptables -t nat -N "$CHAIN_PRE"
            iptables -t nat -C PREROUTING -j "$CHAIN_PRE" 2>/dev/null \
              || iptables -t nat -I PREROUTING -j "$CHAIN_PRE"

            iptables -t nat -n --list "$CHAIN_POST" >/dev/null 2>&1 \
              || iptables -t nat -N "$CHAIN_POST"
            iptables -t nat -C POSTROUTING -j "$CHAIN_POST" 2>/dev/null \
              || iptables -t nat -I POSTROUTING -j "$CHAIN_POST"

            # Guests have no route to the LAN — their default route is qemu's
            # SLIRP gateway — so a DNATed request must come back to them from
            # the bridge address, not from the original client. Hence SNAT on
            # the way in. Without it the guest answers a LAN client down
            # SLIRP and the connection just hangs.
            iptables -t nat -C "$CHAIN_POST" -d "$SUBNET" -o "$BRIDGE" -j MASQUERADE 2>/dev/null \
              || iptables -t nat -A "$CHAIN_POST" -d "$SUBNET" -o "$BRIDGE" -j MASQUERADE
          }

          # The interface the default route leaves by — recomputed on every
          # call so this survives wifi/ethernet switches and reboots.
          wan() {
            ip route show default | awk '{for (i=1;i<NF;i++) if ($i=="dev") print $(i+1)}' | head -1
          }

          case "''${1:-}" in
            add)
              [ $# -eq 4 ] || die "usage: scoite-lan add <guest-ip> <guest-port> <lan-port>"
              init
              gip=$2; gport=$3; lport=$4
              wan_if=$(wan)
              [ -n "$wan_if" ] || die "no default route - nothing to expose on"
              iptables -t nat -A "$CHAIN_PRE" -i "$wan_if" -p tcp --dport "$lport" \
                -m comment --comment "scoite:$lport:$gip:$gport" \
                -j DNAT --to-destination "$gip:$gport"
              echo "exposed $wan_if:$lport -> $gip:$gport"
              ;;
            del)
              [ $# -eq 2 ] || die "usage: scoite-lan del <lan-port>"
              lport=$2
              # Delete by rule number, highest first, so earlier indices stay
              # valid while the loop runs.
              iptables -t nat -n --line-numbers --list "$CHAIN_PRE" 2>/dev/null \
                | grep "scoite:$lport:" \
                | awk '{print $1}' | sort -rn \
                | while read -r n; do iptables -t nat -D "$CHAIN_PRE" "$n"; done
              ;;
            list)
              iptables -t nat -n --list "$CHAIN_PRE" 2>/dev/null \
                | grep -o 'scoite:[0-9]*:[0-9.]*:[0-9]*' || true
              ;;
            *)
              die "usage: scoite-lan add|del|list ..."
              ;;
          esac
        '';
      };
    in
    {
      # Owned by df, not root: scoite's qemu process (and its built-in 9p
      # server for this share) runs as df, not root, so root:root 0700 here
      # would make the guest's sshd unable to read its own host key.
      systemd.tmpfiles.rules = [
        "d /var/lib/scoite 0700 df users - -"
        "d /var/lib/scoite/hostkey 0700 df users - -"
      ];

      # A binary cache in front of this host's own /nix/store, on loopback
      # only. Guests reach it at qemu's SLIRP gateway (http://10.0.2.2:5000 —
      # see nix.settings.substituters in virtualisation/microvm-guest.nix), so
      # anything abhaile has already built or downloaded is copied in at
      # loopback speed instead of being rebuilt or refetched from
      # cache.nixos.org. Guests already mount this exact store read-only, so
      # serving it to them grants nothing new — which is why it runs unsigned
      # (no signKeyPaths) and the guest sets require-sigs = false: no key to
      # manage just to talk to ourselves.
      services.harmonia.cache = {
        enable = true;
        settings.bind = "127.0.0.1:5000";
      };

      # --- the scoite bridge ------------------------------------------------
      # Made with plain iproute2 rather than networking.bridges/systemd.network:
      # abhaile's networking is NetworkManager's, and this bridge wants to be
      # invisible to it — no DHCP client, no connectivity checks, no
      # "connection" NM might tear down. It carries no uplink, only taps.
      systemd.services.scoite-bridge = {
        description = "Bridge for scoite microVM guests (${bridge})";
        wantedBy = [ "multi-user.target" ];
        before = [ "dnsmasq-scoite.service" ];
        after = [ "network-pre.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        path = [ pkgs.iproute2 ];
        script = ''
          ip link show ${bridge} >/dev/null 2>&1 || ip link add ${bridge} type bridge
          ip addr replace ${hostIp}/${toString prefix} dev ${bridge}
          ip link set ${bridge} up

          # Tailscale, with --accept-routes, installs `ip rule ... lookup 52`
          # at priority 5270, and table 52 holds a route for every subnet any
          # peer advertises — including, on this tailnet, ${subnet}. That rule
          # sits *above* the main table (32766), so without this the host
          # sends packets for its own guests down tailscale0 and every ping,
          # ssh and curl to a sandbox black-holes while DHCP (which is L2)
          # keeps working and hides the problem. Same failure mode libvirt's
          # 192.168.122.0/24 has on this host.
          ip rule del to ${subnet} lookup main priority ${toString rulePriority} 2>/dev/null || true
          ip rule add to ${subnet} lookup main priority ${toString rulePriority}
        '';
        # Deliberately does NOT delete the bridge: every running guest's tap is
        # enslaved to it, and `ip link del` silently detaches them all — the
        # sandboxes keep running (SLIRP is a separate NIC) but become
        # unreachable on the bridge until they are restarted. Learned the hard
        # way on 2026-08-25 by restarting this unit under a live guest. The
        # bridge is idle and costs nothing when no guest is up, so it stays.
        preStop = ''
          ip rule del to ${subnet} lookup main priority ${toString rulePriority} 2>/dev/null || true
        '';
      };

      networking.networkmanager.unmanaged = [ "interface-name:${bridge}" ];

      environment.systemPackages = [ scoite-lan ];

      # DNAT is useless without forwarding. Already 1 on this host (libvirt
      # and tailscale both want it) — set explicitly so a host that carries
      # this aspect alone still works.
      boot.kernel.sysctl."net.ipv4.ip_forward" = true;

      # Guests are as trusted as the sandbox model makes them — which is to
      # say the host firewall is not what isolates them (their egress goes out
      # through SLIRP, and nothing on the bridge is routed anywhere). Trusting
      # the interface is what lets DHCP (67/udp), mDNS (5353/udp) and a
      # guest's replies through without a rule per protocol.
      networking.firewall.trustedInterfaces = [ bridge ];

      # qemu's setuid bridge helper is what lets an unprivileged `scoite`
      # attach a tap to the bridge (microvm.nix's type = "bridge" runs
      # /run/wrappers/bin/qemu-bridge-helper). The wrapper and
      # /etc/qemu/bridge.conf both come from the libvirtd module, so extend
      # its allow-list rather than fighting it for ownership of that file.
      # `virbr0` is repeated deliberately: an option's *default* is not a
      # definition, so assigning here replaces `[ "virbr0" ]` rather than
      # merging with it, and dropping it would break libvirt's own VMs.
      virtualisation.libvirtd.allowedBridges = [
        "virbr0"
        bridge
      ];
      assertions = [
        {
          assertion = config.virtualisation.libvirtd.enable;
          message = "virtualization.microvm-host needs libvirtd for /run/wrappers/bin/qemu-bridge-helper (include virtualization.libvirt)";
        }
      ];

      # DHCP only — `port=0` turns the DNS server off entirely, so this can
      # never race systemd-resolved for :53, and names are mDNS's job (S9).
      # A private instance rather than services.dnsmasq: libvirtd runs its own
      # dnsmasq per virtual network and the two must not share a config.
      systemd.services.dnsmasq-scoite = {
        description = "DHCP for the scoite bridge (${bridge})";
        wantedBy = [ "multi-user.target" ];
        after = [ "scoite-bridge.service" ];
        requires = [ "scoite-bridge.service" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = ''
            ${lib.getExe pkgs.dnsmasq} --keep-in-foreground --log-facility=- \
              --port=0 \
              --interface=${bridge} --bind-interfaces --except-interface=lo \
              --dhcp-authoritative \
              --dhcp-range=${dhcpFrom},${dhcpTo},12h \
              --dhcp-leasefile=/var/lib/scoite/dnsmasq.leases
          '';
          Restart = "on-failure";
          RestartSec = 2;
        };
      };

      # Don't rely on the tmpfiles rule above having already run by the time
      # this fires — activation script ordering vs. tmpfiles isn't
      # guaranteed, so this makes its own directory too.
      system.activationScripts.scoiteHostkey = ''
        # Renamed from /var/lib/sandvm (2026-08-24): move the existing key
        # rather than generating a new one. Instances reuse loopback addresses
        # (127.x.y.1), so a changed host key would collide with the entries
        # already in ~/.ssh/known_hosts for those addresses.
        if [ -d /var/lib/sandvm ] && [ ! -d /var/lib/scoite ]; then
          mv /var/lib/sandvm /var/lib/scoite
        fi
        mkdir -p /var/lib/scoite/hostkey
        if [ ! -f /var/lib/scoite/hostkey/ssh_host_ed25519_key ]; then
          ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -C "scoite" \
            -f /var/lib/scoite/hostkey/ssh_host_ed25519_key
        fi
        chown -R df:users /var/lib/scoite
      '';
    };
}
