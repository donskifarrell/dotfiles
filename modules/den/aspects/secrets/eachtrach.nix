# modules/den/aspects/secrets/eachtrach.nix
#
# eachtrach-only secrets. Include in the eachtrach host alongside secrets.sops:
#
#   den.aspects.eachtrach.includes = with den.aspects; [ ... secrets.eachtrach ];
#
# eachtrach is deliberately NOT a recipient of secrets/shared.yaml. It is an
# internet-facing VPS, and shared.yaml holds df's GitHub ssh private keys and
# gitconfigs; a host recipient there could decrypt all of it. So its tailscale
# auth key lives in its own file, encrypted only to &admin_df and
# &host_eachtrach (.sops.yaml), and this aspect points authKeyFile at it
# instead of including services.tailscale.authkey.
#
# The key itself is only needed for a fresh join or a re-login — eachtrach has
# been on the tailnet since 2025-10-26 and stays connected without it (see the
# header of services/tailscale.nix). Auth keys expire ~90d, so if this one is
# ever actually needed it will most likely have to be re-minted first:
#   `sops secrets/eachtrach.yaml`, key `tailscale/eachtrach_authkey`.
#
# eachtrach's root password is NOT managed here. It was set in the clan era and
# survives in /etc/shadow because NixOS defaults to mutableUsers = true; it is
# the only way into Hetzner's web console, so it is left alone rather than
# replaced by a hash this repo would then have to own.
#
# DO NOT manage eachtrach's /etc/ssh/ssh_host_ed25519_key via sops — it is the
# key sops-nix decrypts with.
{ inputs, ... }:
{
  den.aspects.secrets.eachtrach.nixos =
    { config, ... }:
    {
      sops.secrets."eachtrach-tailscale-authkey" = {
        sopsFile = inputs.self + "/secrets/eachtrach.yaml";
        key = "tailscale/eachtrach_authkey";
        mode = "0400";
      };

      services.tailscale.authKeyFile = config.sops.secrets."eachtrach-tailscale-authkey".path;
    };
}
