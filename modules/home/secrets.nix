{
  config.flake.homeModules.secrets =
    args@{
      config,
      lib,
      pkgs,
      ...
    }:

    let
      osConfig = args.osConfig or null;

      hasGen =
        osConfig != null
        && osConfig ? clan
        && osConfig.clan ? core
        && osConfig.clan.core ? vars
        && osConfig.clan.core.vars ? generators
        && osConfig.clan.core.vars.generators ? ssh-aon-clan-test;

      gen = if hasGen then osConfig.clan.core.vars.generators.ssh-aon-clan-test else null;
    in
    {
      options.secrets.ssh = {
        addLocalConfig = lib.mkOption {
          type = lib.types.bool;
          description = "Whether to add include sshconfig.local file in ssh config";
          default = false;
        };

        addKeys = lib.mkOption {
          type = lib.types.bool;
          description = "Whether to add SSH keys to ~/.ssh";
          default = false;
        };
      };

      config = lib.mkIf hasGen {

        home.file.".ssh/ssh-aon-clan-test_key".source =
          config.lib.file.mkOutOfStoreSymlink
            gen.files."ssh-aon-clan-test_key".path;

        # home.file.".ssh/ssh-aon-clan-test_key.pub".source =
        #   config.lib.file.mkOutOfStoreSymlink
        #     gen.files."ssh-aon-clan-test_key.pub".path;
      };
    };
}
