# herdr (herdr.dev) — terminal multiplexer for coding-agent sessions, from
# numtide's nix-ai-tools flake (not nixpkgs).
#
# **Included by nothing since 2026-08-26 (df's call).** The aspect is kept
# intact so re-enabling it is one `includes` line — add `dev.tools.herdr` to
# roles/dev.nix for the host, and `dev.tools.herdr` +
# `dev.tools.herdr.autostart` to the `dev` tier in roles/sandbox.nix for
# guests. If you do bring the autostart back in a sandbox, remember that
# herdr's *own* `terminal.new_cwd` policy decides where a pane starts (it
# defaults to $HOME regardless of the launching shell's cwd) and that it
# persists its session in ~/.config/herdr/session.json on the guest's home
# volume — both bit us in TASKS.md S17.
#
# When it was live: installed on the host so `herdr --remote scoite-<name>`
# could attach to a guest's session over the ssh alias `scoite` sets up —
# herdr tunnels over plain ssh, no daemon/server toggle needed on either end.
{ inputs, ... }:
{
  den.aspects.dev.tools.herdr = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.herdr ];
      };

    # Startup multiplexer for sandbox guests (roles.sandbox.dev): interactive
    # SSH logins land straight in herdr — the sandbox analogue of
    # shell.zellij's auto-start on real hosts. Guards:
    #   - SSH_TTY: only real ssh logins. The qemu serial console stays plain
    #     fish (it's the debug fallback for when SSH itself is broken), and so
    #     do VSCode-remote terminals (spawned by its server, no SSH_TTY).
    #   - HERDR_ENV: herdr sets it to 1 inside its own panes — no recursion.
    # `exec` so detaching/quitting herdr ends the ssh session, matching
    # zellij's exitShellOnExit behaviour.
    # The `cd` keeps a *non-herdr* shell (the serial console, a VS Code
    # terminal, herdr missing) in the sandbox's project directory. It does NOT
    # decide where herdr's panes start: herdr applies its own `terminal.new_cwd`
    # policy, which defaults to $HOME when there is no source workspace, no
    # matter what the launching shell's cwd was (measured 2026-08-25: the herdr
    # server's own /proc/<pid>/cwd was /workspace while its pane reported
    # /home/iosta). The sandbox sets that policy in roles/sandbox.nix.
    # Guarded on /workspace existing, so it is inert on real hosts.
    autostart.homeManager = {
      programs.fish.interactiveShellInit = ''
        if set -q SSH_TTY; and not set -q HERDR_ENV; and type -q herdr
          if test -d /workspace; and test "$PWD" = "$HOME"
            cd /workspace
          end
          exec herdr
        end
      '';
    };
  };
}
