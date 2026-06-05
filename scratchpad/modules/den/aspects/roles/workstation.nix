# role-workstation — the concerns shared by any interactive developer machine
# (desktop today; a dev guest later). Base system + shell/dev/cli home apps.
# It does NOT pull in a DE, GPU, or gaming — that is role-desktop's job.
{ den, ... }:
{
  den.aspects.roles.workstation.includes = with den.aspects; [
    # Base system
    core.nix
    core.i18n
    core.openssh
    core.networking
    core.shell
    core.nh

    # Shell
    apps.shell.fish
    apps.shell.atuin
    apps.shell.eza
    apps.shell.starship
    apps.shell.yazi
    apps.shell.zellij
    apps.shell.zoxide
    apps.terminals.ghostty

    # Dev
    apps.dev.git
    apps.dev.direnv
    apps.dev.neovim
    apps.dev.ssh

    # Batteries
    apps.cli
    apps.xdg
    apps.packages
  ];
}
