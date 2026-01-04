{
  config.flake.nixosModules.secrets-sops =
    { lib, ... }:
    let
      helpers = import ../../lib/mkClanSecretGenerators.nix { inherit lib; };

      mkSecretFiles = helpers.mkClanSecretGenerators;
    in
    {
      config = {
        clan.core.vars.generators =
          (mkSecretFiles {
            folderPath = "ssh";
            group = "secrets";
            files = {
              "sshconfig.local" = "0640";
              "aon.clan.pub" = "0644";
              "aon.clan" = "0640";
              "df_gh.pub" = "0644";
              "df_gh" = "0640";
              "ff_gh.pub" = "0644";
              "ff_gh" = "0640";
              "pgstar_gh.pub" = "0644";
              "pgstar_gh" = "0640";
              "uf_gh.pub" = "0644";
              "uf_gh" = "0640";
            };
          })
          // (mkSecretFiles {
            folderPath = "git";
            group = "secrets";
            files = {
              "gitconfig.local" = "0644";
              "gitconfig.df" = "0644";
              "gitconfig.ff" = "0644";
              "gitconfig.pgstar" = "0644";
              "gitconfig.uf" = "0644";
            };
          });
      };
    };
}
