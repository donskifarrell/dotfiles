# apps/dev/lang/nix — Nix development tooling: formatter (nixfmt), unit testing
# (nix-unit), eval jobs, nixpkgs-review, npins, and nix-your-shell (wraps
# `nix shell`/`develop` to keep your fish prompt). Ported from sini-nix
# modules/den/aspects/apps/dev/lang/nix.nix.
{
  den.aspects.dev.lang.nix.homeManager =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        nix-eval-jobs
        nix-unit
        nixfmt
        nixpkgs-review
        npins
      ];

      programs.nix-your-shell.enable = true;
    };
}
