# herdr (herdr.dev) — terminal multiplexer for coding-agent sessions, from
# numtide's nix-ai-tools flake (not nixpkgs). Installed on the host so
# `herdr --remote sandvm-<name>` can attach to a sandvm guest's session over
# the ssh alias `sandvm` already sets up — herdr tunnels over plain ssh, no
# daemon/server toggle or extra config needed on either end.
{ inputs, ... }:
{
  den.aspects.dev.tools.herdr = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ inputs.nix-ai-tools.packages.${pkgs.system}.herdr ];
      };
  };
}
