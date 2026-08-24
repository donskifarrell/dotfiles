# `sandvm` is this flake's own package (pkgs/by-name/sandvm), not a nixpkgs
# attribute — there's no overlay merging pkgs/by-name into the nixpkgs
# instance NixOS/home-manager modules see, so it has to be referenced via
# `inputs.self.packages`, the same way modules/flake-parts/devshell.nix
# reaches pkgs/by-name packages via `config.packages.<name>` in the
# flake-parts (not module-system) context.
#
# (Named `sandvm`, not `devbox`: nixpkgs already has an unrelated package
# literally called `devbox` — Jetify's tool — which `pkgs.devbox` would have
# silently resolved to instead.)
{ inputs, ... }:
{
  den.aspects.dev.tools.sandvm = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.sandvm ];

        # SSH-agent forwarding into sandboxes (git push/pull auth without any
        # key material in the guest — the agent only ever *signs* on the
        # guest's behalf, over the live connection). It must live HERE, not in
        # the per-instance blocks the wrapper writes into ~/.ssh/config.d/:
        # ssh_config is first-match-wins per keyword, and core.network.ssh's
        # `Host *` sets `ForwardAgent no` *before* the `Include
        # ~/.ssh/config.d/*` line — anything in those files is shadowed. This
        # block instead rides home-manager's guarantee that non-"*" settings
        # blocks render before the "*" default block, so it wins.
        programs.ssh.settings."sandvm-*".ForwardAgent = true;

        # Keep running sandboxes' credentials current (2026-08-23). A guest's
        # /run/agent.env — the omp auth-broker URL + bearer token it needs to
        # reach the host's credential store — is written once, at its own boot.
        # Everything downstream of it is live (the broker re-reads its store
        # when df logs a provider back in, and a guest's omp queries the broker
        # per request), so that boot snapshot is the single stale link: a
        # sandbox launched before `omp auth-broker login`, or still running
        # when the bearer token is rotated, could only be fixed by a
        # stop/start. `sandvm creds --all` re-pushes it into every *running*
        # sandbox; `sandvm ssh` does the same on attach, so this timer is
        # really for the headless ones nobody attaches to.
        #
        # No-ops (silently, exit 0) when nothing is running.
        systemd.user.services.sandvm-creds = {
          Unit.Description = "Re-push host credentials into running sandvm guests";
          Service = {
            Type = "oneshot";
            ExecStart = "${
              inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.sandvm
            }/bin/sandvm creds --all";
          };
        };

        systemd.user.timers.sandvm-creds = {
          Unit.Description = "Periodic sandvm guest credential refresh";
          Timer = {
            OnBootSec = "5min";
            OnUnitActiveSec = "10min";
            AccuracySec = "1min";
          };
          Install.WantedBy = [ "timers.target" ];
        };

        # Launch the isolated vault agent (Claude in a microVM that sees only
        # ~/vaults/main) — docs/obsidian.md. Lives here, not in apps.obsidian,
        # so the abbr only exists where `sandvm` itself does.
        programs.fish.shellAbbrs.vault-agent = "sandvm ~/vaults/main";
      };
  };
}
