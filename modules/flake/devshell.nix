# `nix develop` shell: the formatter plus deploy + secrets tooling.
_: {
  perSystem =
    { config, pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        packages = [
          config.treefmt.build.wrapper
          pkgs.statix
          pkgs.deadnix

          # Deploy + secrets tooling.
          pkgs.deploy-rs
          pkgs.nixos-anywhere
          pkgs.sops
          pkgs.ssh-to-age
          pkgs.age
        ];
      };
    };
}
