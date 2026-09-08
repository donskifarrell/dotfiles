# Tailnet-only reverse proxy. This is a BASE aspect: it enables caddy and
# nothing else. Every site is declared by the service that owns it (see
# services/bbm.nix), so hosting one more thing never means editing this file.
#
# Rewritten 2026-09-05 for eachtrach. It previously carried a hardcoded
# `short.tail8f3a60.ts.net` vhost reverse-proxying a syncthing that runs on no
# current host — TODO item 12's orphan. Deleted rather than ported: nothing
# referenced it and "short" is not a machine in this repo.
#
# **Reachability is not this file's doing.** services.tailscale sets
# `networking.firewall.trustedInterfaces = [ "tailscale0" ]`, so every port is
# already reachable over WireGuard, and eachtrach opens only 22/tcp + 41641/udp
# on its public NIC. The `interfaces.tailscale0.allowedTCPPorts = [ 80 443 ]`
# this file used to carry was therefore a no-op, and is gone.
#
# Do NOT add `networking.firewall.allowedTCPPorts` here. That list is not
# per-interface: it would open the port on the PUBLIC interface of an
# internet-facing VPS, which is the one thing this setup must not do.
#
# Binding caddy to the tailnet address instead of 0.0.0.0 was considered as
# defence in depth and rejected: it makes caddy's startup depend on tailscaled
# having brought the interface up, which turns a transient tailscale hiccup
# into a failed activation (and, under deploy-rs, a rollback) — in exchange for
# nothing the firewall does not already guarantee.
{
  den.aspects.services.web.caddy = {
    nixos = {
      services.caddy.enable = true;
    };

    # Sub-aspect, NOT implied by the parent (same convention as
    # services.tailscale.*): let caddy ask tailscaled for a real Let's Encrypt
    # certificate for this machine's `<host>.<tailnet>.ts.net` name, which
    # caddy does automatically for a `.ts.net` site address.
    #
    # Not currently included anywhere — bbm ships on plain HTTP over the
    # tailnet (see services/bbm.nix, `useTLS`). Enabling it needs the tailnet
    # admin console's DNS -> HTTPS Certificates toggle ON first; without that,
    # cert issuance fails and caddy will not serve the site at all.
    tailscale-tls.nixos = {
      services.tailscale.permitCertUid = "caddy";
    };
  };
}
