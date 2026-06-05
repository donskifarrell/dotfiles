# The graphical productivity apps that machines/abhaile/configuration.nix
# enabled inline in its home-manager block (element, obsidian, onlyoffice).
{
  den.aspects.apps.productivity.apps.homeManager = {
    programs.element-desktop.enable = true;
    programs.obsidian.enable = true;
    programs.onlyoffice.enable = true;
  };
}
