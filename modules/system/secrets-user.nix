# modules/system/secrets-user.nix  (rewritten for sops-nix)
#
# Replaces the Clan-vars version. Symlinks the runtime secrets that sops-nix
# materialises under /run/secrets into df's ~/.ssh and ~/.config/git, exactly as
# before - but the source paths now come from `config.sops.secrets.<name>.path`
# instead of the old /run/secrets/vars/<generator>/<file> convention.
#
# Pairs with modules/den/aspects/secrets/sops.nix (which declares the secrets).
{
  config.flake.nixosModules.secrets-user =
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
          default = config.my.mainUser.name;
        };
        home = lib.mkOption {
          type = lib.types.str;
          default = "/home/${config.my.mainUser.name}";
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
