# treefmt-nix: strict nixfmt + statix + deadnix, exposed as `nix fmt` and as the
# flake's `formatter`. Also contributes a `treefmt` flake check per system.
{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem =
    { config, ... }:
    {
      treefmt = {
        projectRootFile = "flake.nix";
        programs = {
          nixfmt.enable = true;
          statix.enable = true;
          deadnix.enable = true;
        };
      };

      formatter = config.treefmt.build.wrapper;
    };
}
