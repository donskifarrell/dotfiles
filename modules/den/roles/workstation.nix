# role-workstation — the concerns shared by any interactive developer machine
# (desktop today; a dev guest later). Base system + shell/dev/cli home apps.
# It does NOT pull in a DE, GPU, or gaming — that is role-desktop's job.
{ den, ... }:
{
  den.aspects.roles.workstation.includes = with den.aspects; [
    core.network.ssh
    core.nix.nix-index

    apps.bundles.browsers
    apps.bundles.media
    apps.bundles.security
    apps.bundles.social

    apps.ai-tools
    apps.ghostty

    shell
    shell.atuin
    shell.bat
    shell.delta
    shell.difftastic
    shell.eza
    shell.fish
    shell.neovim
    shell.starship
    shell.yazi
    shell.zellij
    shell.zoxide

    shell.bundles.archive
    shell.bundles.base
    shell.bundles.data
    shell.bundles.search
    shell.bundles.system
  ];
}
