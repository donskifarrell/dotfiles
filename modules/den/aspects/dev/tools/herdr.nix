# herdr (herdr.dev) — terminal multiplexer for coding-agent sessions, from
# numtide's nix-ai-tools flake (not nixpkgs). Installed on the host so
# `herdr --remote sandvm-<name>` can attach to a sandvm guest's session over
# the ssh alias `sandvm` already sets up — herdr tunnels over plain ssh, no
# daemon/server toggle or extra config needed on either end.
{ inputs, ... }:
{
  den.aspects.dev.tools.herdr = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ inputs.nix-ai-tools.packages.${pkgs.system}.herdr ];
      };

    # Startup multiplexer for sandbox guests (roles.dev-sandbox): interactive
    # SSH logins land straight in herdr — the sandbox analogue of
    # shell.zellij's auto-start on real hosts. Guards:
    #   - SSH_TTY: only real ssh logins. The qemu serial console stays plain
    #     fish (it's the debug fallback for when SSH itself is broken), and so
    #     do VSCode-remote terminals (spawned by its server, no SSH_TTY).
    #   - HERDR_ENV: herdr sets it to 1 inside its own panes — no recursion.
    # `exec` so detaching/quitting herdr ends the ssh session, matching
    # zellij's exitShellOnExit behaviour.
    autostart.homeManager = {
      programs.fish.interactiveShellInit = ''
        if set -q SSH_TTY; and not set -q HERDR_ENV; and type -q herdr
          exec herdr
        end
      '';
    };
  };
}
