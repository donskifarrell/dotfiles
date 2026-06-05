# The small CLI tools that machines/*/configuration.nix enabled inline in their
# home-manager blocks (bat, btop, fd, fzf, jq, ripgrep, trippy, nix-index).
# Consolidated into one "every shell wants these" aspect.
{
  den.aspects.apps.cli.homeManager = {
    programs = {
      bat.enable = true;
      btop.enable = true;
      fd.enable = true;
      fzf.enable = true;
      jq.enable = true;
      ripgrep.enable = true;
      trippy.enable = true;

      nix-index = {
        enable = true;
        enableFishIntegration = true;
      };
    };
  };
}
