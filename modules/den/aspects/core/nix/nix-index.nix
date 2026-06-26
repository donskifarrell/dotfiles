{ inputs, ... }:
{
  den.aspects.core.nix.nix-index = {
    os = _: {
      home-manager.sharedModules = [ inputs.nix-index-database.homeModules.default ];
    };

    homeManager = {
      programs.nix-index-database.comma.enable = true;
      programs.command-not-found.enable = false;
      programs.nix-index = {
        enable = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
      };
    };
  };
}
