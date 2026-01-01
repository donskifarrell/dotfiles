{
  config.flake.nixosModules.sops-secrets =
    { lib, ... }:
    let
      helpers = import ./helpers/mkClanFileGenerators.nix { inherit lib; };

      mk = helpers.mkClanFileGenerators;
    in
    {
      config = {
        clan.core.vars.generators =
          (mk {
            folderPath = "ssh/df";
            files = {
              "df_key" = "0600";
              "df_key.pub" = "0644";
            };
          })
          // (mk {
            folderPath = "ssh/uf";
            files = {
              "uf_key" = "0600";
              "uf_key.pub" = "0644";
            };
          });
      };
    };
  # { ... }:
  # {
  #   config = {
  #     clan.core.vars.generators."ssh/aon-clan-test" = {
  #       share = true;

  #       prompts = {
  #         private-key = {
  #           description = "The private key contents";
  #           type = "multiline";
  #         };
  #         public-key = {
  #           description = "The public key contents";
  #           type = "multiline";
  #         };
  #       };

  #       files."ssh-aon-clan-test_key" = {
  #         secret = true;
  #         mode = "0600";
  #       };
  #       files."ssh-aon-clan-test_key.pub" = {
  #         secret = true;
  #         mode = "0644";
  #       };

  #       script = ''
  #         cat "$prompts"/private-key > "$out"/ssh-aon-clan-test_key
  #         cat "$prompts"/public-key > "$out"/ssh-aon-clan-test_key.pub
  #       '';
  #     };

  #     clan.core.vars.generators."ssh/aon-git-test" = {
  #       share = true;

  #       prompts = {
  #         private-key = {
  #           description = "The private key contents";
  #           type = "multiline";
  #         };
  #         public-key = {
  #           description = "The public key contents";
  #           type = "multiline";
  #         };
  #       };

  #       files."git-aon-clan-test_key" = {
  #         secret = true;
  #         mode = "0600";
  #       };
  #       files."git-aon-clan-test_key.pub" = {
  #         secret = true;
  #         mode = "0644";
  #       };

  #       script = ''
  #         cat "$prompts"/private-key > "$out"/git-aon-clan-test_key
  #         cat "$prompts"/public-key > "$out"/git-aon-clan-test_key.pub
  #       '';
  #     };
  #   };
  # };
}
