# dev.lang.node — a baseline Node.js on PATH (24.x from nixpkgs), plus the two
# package managers that are not bundled with it.
#
# Same rationale as dev.lang.python: per-project toolchains belong in
# devenv.nix/flake.nix, and a project that declares its own Node wins on PATH
# via direnv. This is the always-available fallback, which is what an agent in
# a `dev` sandbox needs before it has read the project's environment — and what
# makes a bare `npx`/`node script.js` work in a folder with no devenv at all.
#
# npm and npx ship inside the nodejs derivation. corepack is deliberately NOT
# installed: it collides with nodejs over the same `corepack` binary, and pnpm
# from nixpkgs covers the same ground without the file-conflict.
{
  den.aspects.dev.lang.node.homeManager =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.nodejs
        pkgs.pnpm
        pkgs.bun
      ];
    };
}
