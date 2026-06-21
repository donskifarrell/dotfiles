# apps/dev/lang/go — Go toolchain + gotools (goimports, etc.). Matches the Go
# tooling configured in apps/dev/vscode. Ported from sini-nix
# modules/den/aspects/apps/dev/lang/go.nix.
{
  den.aspects.dev.lang.go.homeManager =
    { pkgs, ... }:
    {
      programs.go.enable = true;
      home.packages = [ pkgs.gotools ];
    };
}
