# `sandvm` is this flake's own package (pkgs/by-name/sandvm), not a nixpkgs
# attribute — there's no overlay merging pkgs/by-name into the nixpkgs
# instance NixOS/home-manager modules see, so it has to be referenced via
# `inputs.self.packages`, the same way modules/flake-parts/devshell.nix
# reaches pkgs/by-name packages via `config.packages.<name>` in the
# flake-parts (not module-system) context.
#
# (Named `sandvm`, not `devbox`: nixpkgs already has an unrelated package
# literally called `devbox` — Jetify's tool — which `pkgs.devbox` would have
# silently resolved to instead.)
{ inputs, ... }:
{
  den.aspects.dev.tools.sandvm = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ inputs.self.packages.${pkgs.system}.sandvm ];
      };
  };
}
