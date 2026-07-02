# modules/den/aspects/secrets/home.nix
#
# df's home secrets (~/.ssh keys + config, ~/.config/git identities), all from
# secrets/shared.yaml. ONE line per secret in `homeFiles` below; everything
# else (sops.secrets entry, /run/secrets name, mode, home symlink) is derived.
#
# To add a home secret: `sops secrets/shared.yaml` (add the key/value), then
# add one map line here. Requires the secrets.sops base aspect on the same
# host. Including this aspect activates it (dendritic — no enable flag).
#
# Derivation rules:
#   /run/secrets name = yaml key with "/" -> "-"  (ssh/df_gh -> ssh-df_gh)
#   mode              = ssh/* without _pub suffix -> 0600, else 0644
#   owner             = df (no group indirection; sops-nix orders after users)
{ inputs, ... }:
let
  sharedFile = inputs.self + "/secrets/shared.yaml";

  user = "df";
  home = "/home/df";

  # yaml key in secrets/shared.yaml -> destination relative to $HOME
  homeFiles = {
    "ssh/sshconfig_local" = ".ssh/sshconfig.local";
    "ssh/aon_clan" = ".ssh/aon.clan";
    "ssh/aon_clan_pub" = ".ssh/aon.clan.pub";
    "ssh/df_gh" = ".ssh/df_gh";
    "ssh/df_gh_pub" = ".ssh/df_gh.pub";
    "ssh/ff_gh" = ".ssh/ff_gh";
    "ssh/ff_gh_pub" = ".ssh/ff_gh.pub";
    "ssh/pgstar_gh" = ".ssh/pgstar_gh";
    "ssh/pgstar_gh_pub" = ".ssh/pgstar_gh.pub";
    "ssh/uf_gh" = ".ssh/uf_gh";
    "ssh/uf_gh_pub" = ".ssh/uf_gh.pub";
    "git/gitconfig_local" = ".config/git/gitconfig.local";
    "git/gitconfig_df" = ".config/git/gitconfig.df";
    "git/gitconfig_ff" = ".config/git/gitconfig.ff";
    "git/gitconfig_pgstar" = ".config/git/gitconfig.pgstar";
    "git/gitconfig_uf" = ".config/git/gitconfig.uf";
  };
in
{
  den.aspects.secrets.home.nixos =
    { lib, config, ... }:
    let
      secretName = key: lib.replaceStrings [ "/" ] [ "-" ] key;
      isPrivate = key: lib.hasPrefix "ssh/" key && !lib.hasSuffix "_pub" key;
    in
    {
      sops.secrets = lib.mapAttrs' (
        key: _dest:
        lib.nameValuePair (secretName key) {
          sopsFile = sharedFile;
          inherit key;
          owner = user;
          mode = if isPrivate key then "0600" else "0644";
        }
      ) homeFiles;

      systemd.tmpfiles.rules = [
        "d ${home}/.ssh 0700 ${user} users - -"
        "d ${home}/.config 0755 ${user} ${user} - -"
        "d ${home}/.config/git 0700 ${user} users - -"
      ]
      ++ lib.mapAttrsToList (
        key: dest: "L+ ${home}/${dest} - - - - ${config.sops.secrets.${secretName key}.path}"
      ) homeFiles;
    };
}
