# Ported from modules/home/claude.nix. The legacy module received `claude-code`
# as a home-manager specialArg; here the aspect closes over the flake `inputs`
# directly, so no specialArg wiring is needed. Requires the `nix-ai-tools` input
# (numtide/nix-ai-tools, formerly llm-agents.nix), which provides `claude-code`.
{ inputs, ... }:
{
  # Intentionally NOT following nixpkgs-unstable: numtide builds + pushes to
  # cache.numtide.com against nix-ai-tools' own locked nixpkgs. Overriding the
  # follows changes derivation hashes and turns claude-code/omp into local
  # rebuilds. Keeping the pin costs a second nixpkgs in the lock but gets cache
  # hits. (Cache configured in aspects/core/nix/nix.nix.)
  flake-file.inputs.nix-ai-tools.url = "github:numtide/nix-ai-tools";

  den.aspects.apps.ai-tools.homeManager =
    { pkgs, ... }:
    {
      home.packages = [
        inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
        inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.omp
      ];
    };
}
