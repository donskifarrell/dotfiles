{
  config.flake.homeModules.claude =
    { claude-code, pkgs, ... }:
    {
      config = {
        home.packages = [
          claude-code.packages.${pkgs.system}.default
        ];
      };
    };
}
