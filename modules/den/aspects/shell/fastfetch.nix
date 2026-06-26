# apps/shell/fastfetch — system-info / fetch tool. Relocated from the orphan
# top-level `shell/` category into apps/shell/ alongside the rest of the shell
# tooling (fish, eza, zoxide, …).
{
  den.aspects.shell.fastfetch.homeManager = {
    programs.fastfetch.enable = true;
  };
}
