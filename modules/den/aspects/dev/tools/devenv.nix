# devenv comes from upstream's flake, not nixpkgs. nixpkgs' devenv 2.3.x links
# a newer libghostty than upstream pins, which breaks interactive `devenv shell`
# with "terminal error: invalid value" (cachix/devenv#3183, 2026-09). Upstream's
# own build is fine. Not following nixpkgs so devenv.cachix.org gets hits
# (cache configured in aspects/core/nix/nix.nix). Revisit: once nixpkgs' devenv
# works again, drop the input and go back to pkgs.devenv.
{ inputs, ... }:
{
  flake-file.inputs.devenv.url = "github:cachix/devenv/v2.3.1";

  den.aspects.dev.tools.devenv = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          inputs.devenv.packages.${pkgs.stdenv.hostPlatform.system}.devenv
        ];
      };
  };
}
