# modules/den/aspects/secrets/abhaile.nix
#
# abhaile-only secrets (passwords + optional machine services). Include this in
# the abhaile host, NOT in roles.default, e.g. in modules/den/hosts/abhaile.nix:
#
#   den.aspects.abhaile.includes = with den.aspects; [ ... secrets.abhaile ];
#
# Password HASHES must exist before users are created, so they use
# `neededForUsers = true` (sops-nix places them under /run/secrets-for-users and
# decrypts them early; owner/mode are forced to root and can't be set here).
#
# Consume them in a users aspect / the host:
#   users.users.df.hashedPasswordFile   = config.sops.secrets."abhaile-df-password-hash".path;
#   users.users.root.hashedPasswordFile = config.sops.secrets."abhaile-root-password-hash".path;
#
# emergency-access is NOT a sops secret: boot.initrd.systemd.emergencyAccess takes
# the hash as a literal string baked into the initrd, so it lives directly in the
# host aspect (modules/den/hosts/abhaile.nix). The old hash was already a public
# clan "value".
{ inputs, ... }:
let
  abhaileFile = inputs.self + "/secrets/abhaile.yaml";
in
{
  den.aspects.secrets.abhaile.nixos = {
    sops.secrets = {
      "abhaile-df-password-hash" = {
        sopsFile = abhaileFile;
        key = "abhaile/user_password_df_hash";
        neededForUsers = true;
      };
      "abhaile-root-password-hash" = {
        sopsFile = abhaileFile;
        key = "abhaile/root_password_hash";
        neededForUsers = true;
      };

      # Optional - syncthing now runs via services.syncthing (vault sync,
      # docs/obsidian.md) with self-generated keys; adopt these only if you
      # want the identity in sops. NOTE: the service runs as df, so owner must
      # be "df" (not "syncthing"). Point services.syncthing.{key,cert} at the
      # .path values when enabling.
      # "abhaile-syncthing-key"  = { sopsFile = abhaileFile; key = "abhaile/syncthing_key";  owner = "df"; mode = "0600"; };
      # "abhaile-syncthing-cert" = { sopsFile = abhaileFile; key = "abhaile/syncthing_cert"; owner = "df"; mode = "0600"; };
      # "abhaile-syncthing-api"  = { sopsFile = abhaileFile; key = "abhaile/syncthing_api";  owner = "df"; mode = "0600"; };
    };
  };

  # DO NOT manage abhaile's openssh host key (vars/.../openssh/ssh.id_ed25519)
  # via sops. It is the very key sops-nix decrypts with - leave the existing
  # /etc/ssh/ssh_host_ed25519_key in place untouched.
}
