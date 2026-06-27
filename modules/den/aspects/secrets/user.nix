# modules/den/aspects/secrets/user.nix
#
# Den aspect form of the old modules/system/secrets-user.nix. Symlinks the
# sops-nix runtime secrets (declared in secrets/sops.nix) into df's ~/.ssh and
# ~/.config/git. Made a Den aspect (not a flake.nixosModule) so the Den-built
# host can `includes` it directly - no flake self-import, no clan `modules`
# specialArg. Enable per-host with `secretsUser.enable = true`.
#
# Defaults to user `df` (the only user with home secrets); the old
# `config.my.mainUser.name` default is gone with options.nix.
{
  den.aspects.secrets.user.nixos =
    { lib, config, ... }:
    let
      cfg = config.secretsUser;

      sec = name: config.sops.secrets.${name}.path;
      link = src: dest: "L+ ${dest} - - - - ${src}";

      # name (in sops.secrets) -> filename under ~/.ssh
      sshMap = {
        "ssh-sshconfig_local" = "sshconfig.local";
        "ssh-aon_clan" = "aon.clan";
        "ssh-aon_clan_pub" = "aon.clan.pub";
        "ssh-df_gh" = "df_gh";
        "ssh-df_gh_pub" = "df_gh.pub";
        "ssh-ff_gh" = "ff_gh";
        "ssh-ff_gh_pub" = "ff_gh.pub";
        "ssh-pgstar_gh" = "pgstar_gh";
        "ssh-pgstar_gh_pub" = "pgstar_gh.pub";
        "ssh-uf_gh" = "uf_gh";
        "ssh-uf_gh_pub" = "uf_gh.pub";
      };

      # name (in sops.secrets) -> filename under ~/.config/git
      gitMap = {
        "git-gitconfig_local" = "gitconfig.local";
        "git-gitconfig_df" = "gitconfig.df";
        "git-gitconfig_ff" = "gitconfig.ff";
        "git-gitconfig_pgstar" = "gitconfig.pgstar";
        "git-gitconfig_uf" = "gitconfig.uf";
      };

      mkLinks =
        destDir: map':
        lib.mapAttrsToList (name: fname: link (sec name) "${cfg.home}/${destDir}/${fname}") map';
    in
    {
      options.secretsUser = {
        enable = lib.mkEnableOption "Symlink sops-nix runtime secrets into the user's home";
        user = lib.mkOption {
          type = lib.types.str;
          default = "df";
        };
        home = lib.mkOption {
          type = lib.types.str;
          default = "/home/df";
        };
      };

      config = lib.mkIf cfg.enable {
        users.groups.secrets = { };
        users.users.${cfg.user}.extraGroups = lib.mkAfter [ "secrets" ];

        systemd.tmpfiles.rules = [
          "d ${cfg.home}/.ssh 0700 ${cfg.user} secrets - -"
          "d ${cfg.home}/.config 0755 ${cfg.user} ${cfg.user} - -"
          "d ${cfg.home}/.config/git 0700 ${cfg.user} secrets - -"
        ]
        ++ mkLinks ".ssh" sshMap
        ++ mkLinks ".config/git" gitMap;
      };
    };
}
