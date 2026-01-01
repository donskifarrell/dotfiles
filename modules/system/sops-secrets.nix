{
  config.flake.nixosModules.sops-secrets =
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
            files = {
              "sshconfig.local" = "0600";
              "aon.clan.pub" = "0644";
              "aon.clan" = "0600";
              "df_gh.pub" = "0644";
              "df_gh" = "0600";
              "ff_gh.pub" = "0644";
              "ff_gh" = "0600";
              "pgstar_gh.pub" = "0644";
              "pgstar_gh" = "0600";
              "uf_gh.pub" = "0644";
              "uf_gh" = "0600";
            };
          })
          // (mkSecretFiles {
            folderPath = "git";
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
