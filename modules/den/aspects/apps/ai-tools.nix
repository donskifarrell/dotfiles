# Ported from modules/home/claude.nix. The legacy module received `claude-code`
# as a home-manager specialArg; here the aspect closes over the flake `inputs`
# directly, so no specialArg wiring is needed. Requires the `nix-ai-tools` input
# (numtide/nix-ai-tools, formerly llm-agents.nix), which provides `claude-code`.
{ inputs, ... }:
{
  flake-file.inputs.nix-ai-tools = {
    url = "github:numtide/nix-ai-tools";
    inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  den.aspects.apps.ai-tools.homeManager =
    { pkgs, ... }:
    {
      home.packages = [ inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.claude-code ];
    };
}

# {
#   inputs = {
#     llm-agents.url = "github:numtide/llm-agents.nix";
#   };

#   # In your system packages:
#   environment.systemPackages = with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
#     claude-code
#     opencode
#     gemini-cli
#     qwen-code
#     # ... other tools
#   ];
# }
