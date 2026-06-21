# Ported from modules/home/claude.nix. The legacy module received `claude-code`
# as a home-manager specialArg; here the aspect closes over the flake `inputs`
# directly, so no specialArg wiring is needed. Requires the `claude-code` input
# (added to flake.nix).
{ inputs, ... }:
{
  den.aspects.apps.dev.claude.homeManager =
    { pkgs, ... }:
    {
      home.packages = [ inputs.claude-code.packages.${pkgs.system}.default ];
    };
}
