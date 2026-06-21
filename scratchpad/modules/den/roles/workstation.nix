# role-workstation — the concerns shared by any interactive developer machine
# (desktop today; a dev guest later). Base system + shell/dev/cli home apps.
# It does NOT pull in a DE, GPU, or gaming — that is role-desktop's job.
{ den, ... }:
{
  den.aspects.roles.workstation.includes = with den.aspects; [

    # Shell
    apps.shell.fish
    apps.shell.atuin
    apps.shell.eza
    apps.shell.starship
    apps.shell.yazi
    apps.shell.zellij
    apps.shell.zoxide
    apps.terminals.ghostty

    # Shell power-tools (ported from sini)
    apps.shell.search # fd / fzf / ripgrep / skim
    apps.shell.process # procs / mprocs / ctop / htop
    apps.shell.disk # dust / dua / dysk / ncdu
    apps.shell.data # yq / tokei / navi / tealdeer / lazysql
    apps.shell.archive # atool + archive formats
    apps.dev.shell.bat # bat + bat-extras

    # Dev
    apps.dev.git
    apps.dev.git.github # gh + gh-dash
    apps.dev.git.lazygit
    apps.dev.direnv
    apps.dev.neovim
    apps.dev.ssh
    apps.dev.security.gpg

    # Dev languages (ported from sini)
    apps.dev.lang.go
    apps.dev.lang.nix
    apps.dev.lang.python

    # Batteries
    apps.cli
    apps.xdg
    apps.packages
  ];
}
