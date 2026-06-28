# modules/den/aspects/secrets/sops.nix
#
# Base secrets aspect for SHARED secrets (df's home ssh/git files + tailscale
# auth key). Include it on every host that needs them; each only decrypts on
# hosts listed as recipients in .sops.yaml. Currently included via the abhaile
# host; promote to roles.default if/when more hosts should carry the shared set.
#
# Host identity = the machine's own /etc/ssh/ssh_host_ed25519_key (via
# age.sshKeyPaths). Nothing to provision: abhaile already has the key, and a
# freshly-installed host has it after first boot. This is the anti-lockout choice.
#
# Modes/owners: owner root, group "secrets"; .pub + gitconfig are 0644, private
# material 0640 (mirrors how these were deployed before).
{ inputs, ... }:
let
  sharedFile = inputs.self + "/secrets/shared.yaml";

  # name (under /run/secrets) -> { key (path inside the yaml), mode }
  # group is "secrets" and owner "root" for all of these.
  sshFiles = {
    "ssh-sshconfig_local" = {
      key = "ssh/sshconfig_local";
      mode = "0640";
    };
    "ssh-aon_clan" = {
      key = "ssh/aon_clan";
      mode = "0640";
    };
    "ssh-aon_clan_pub" = {
      key = "ssh/aon_clan_pub";
      mode = "0644";
    };
    "ssh-df_gh" = {
      key = "ssh/df_gh";
      mode = "0640";
    };
    "ssh-df_gh_pub" = {
      key = "ssh/df_gh_pub";
      mode = "0644";
    };
    "ssh-ff_gh" = {
      key = "ssh/ff_gh";
      mode = "0640";
    };
    "ssh-ff_gh_pub" = {
      key = "ssh/ff_gh_pub";
      mode = "0644";
    };
    "ssh-pgstar_gh" = {
      key = "ssh/pgstar_gh";
      mode = "0640";
    };
    "ssh-pgstar_gh_pub" = {
      key = "ssh/pgstar_gh_pub";
      mode = "0644";
    };
    "ssh-uf_gh" = {
      key = "ssh/uf_gh";
      mode = "0640";
    };
    "ssh-uf_gh_pub" = {
      key = "ssh/uf_gh_pub";
      mode = "0644";
    };
  };

  gitFiles = {
    "git-gitconfig_local" = {
      key = "git/gitconfig_local";
      mode = "0644";
    };
    "git-gitconfig_df" = {
      key = "git/gitconfig_df";
      mode = "0644";
    };
    "git-gitconfig_ff" = {
      key = "git/gitconfig_ff";
      mode = "0644";
    };
    "git-gitconfig_pgstar" = {
      key = "git/gitconfig_pgstar";
      mode = "0644";
    };
    "git-gitconfig_uf" = {
      key = "git/gitconfig_uf";
      mode = "0644";
    };
  };

  # tailscale auth key for abhaile's peer instance (aon-tailnet).
  # NOTE: tailnet auth keys expire (~90d). For an already-joined node it isn't
  # needed to stay connected; mint a fresh one for new joins / fresh installs.
  tailscaleFiles = {
    "tailscale-aon_tailnet-authkey" = {
      key = "tailscale/aon_tailnet_authkey";
      mode = "0400";
    };
  };

  mkSecret = _name: spec: {
    sopsFile = sharedFile;
    inherit (spec) key mode;
    owner = "root";
    group = "secrets";
  };
in
{
  den.aspects.secrets.sops.nixos =
    { lib, ... }:
    {
      imports = [ inputs.sops-nix.nixosModules.sops ];

      # Decrypt using the host's existing SSH host key (age, ed25519).
      sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      # Age is the only method; drop sops-nix's default gnupg-via-rsa fallback so
      # activation doesn't depend on /etc/ssh/ssh_host_rsa_key or attempt GPG.
      sops.gnupg.sshKeyPaths = [ ];

      # Group used by secrets-user.nix symlinks + file ownership.
      users.groups.secrets = { };

      sops.secrets =
        lib.mapAttrs mkSecret sshFiles
        // lib.mapAttrs mkSecret gitFiles
        // lib.mapAttrs mkSecret tailscaleFiles;
    };
}
