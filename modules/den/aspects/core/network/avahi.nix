# core.network.avahi — mDNS/DNS-SD on a real host: discovers printers and other
# machines on the LAN, and (2026-08-25) is what makes a `scoite` sandbox's
# `scoite-<name>.local` name resolve on abhaile. The guests publish over the
# scoitebr0 bridge via systemd-resolved's MulticastDNS; this side has to be
# able to *ask*, which needs both the daemon and the NSS module.
{
  den.aspects.core.network.avahi = {
    nixos = _: {
      services.avahi = {
        enable = true;
        openFirewall = true;

        # Without these, /etc/nsswitch.conf carries no mdns entry and glibc
        # cannot resolve any .local name — `avahi-resolve` works while
        # `getent hosts`, ssh, curl and every browser do not.
        nssmdns4 = true;
        nssmdns6 = true;

        # Answer for this host as well as ask about others: needed for the
        # reverse direction (a guest resolving `abhaile.local`).
        publish = {
          enable = true;
          addresses = true;
          workstation = true;
        };
      };
    };
  };
}
