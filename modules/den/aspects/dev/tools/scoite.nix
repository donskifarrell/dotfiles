# `scoite` is this flake's own package (pkgs/by-name/scoite), not a nixpkgs
# attribute — there's no overlay merging pkgs/by-name into the nixpkgs
# instance NixOS/home-manager modules see, so it has to be referenced via
# `inputs.self.packages`, the same way modules/flake-parts/devshell.nix
# reaches pkgs/by-name packages via `config.packages.<name>` in the
# flake-parts (not module-system) context.
#
# (Named `scoite`, not `devbox`: nixpkgs already has an unrelated package
# literally called `devbox` — Jetify's tool — which `pkgs.devbox` would have
# silently resolved to instead.)
{ inputs, ... }:
{
  den.aspects.dev.tools.scoite = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.scoite ];

        # SSH-agent forwarding into sandboxes (git push/pull auth without any
        # key material in the guest — the agent only ever *signs* on the
        # guest's behalf, over the live connection). It must live HERE, not in
        # the per-instance blocks the wrapper writes into ~/.ssh/config.d/:
        # ssh_config is first-match-wins per keyword, and core.network.ssh's
        # `Host *` sets `ForwardAgent no` *before* the `Include
        # ~/.ssh/config.d/*` line — anything in those files is shadowed. This
        # block instead rides home-manager's guarantee that non-"*" settings
        # blocks render before the "*" default block, so it wins.
        programs.ssh.settings."scoite-*" = {
          ForwardAgent = true;

          # Name the key explicitly (2026-08-26). A guest authorizes exactly
          # one key — df's `aon.clan` (modules/den/users/iosta.nix) — and that
          # private key is passphrase-encrypted, so it is only usable through
          # the agent. Without an IdentityFile here, ssh has *nothing to
          # offer* the moment the agent is empty, and every sandbox answers
          # `Permission denied (publickey)`.
          #
          # The agent empties more often than you would think: home-manager's
          # ssh-agent.service is restarted by `nixos-rebuild switch`, which
          # drops every key added since login. With this block an interactive
          # ssh prompts for the passphrase once and `AddKeysToAgent` puts it
          # back in the agent, which is also what makes agent-forwarded git
          # inside the guest work again.
          IdentityFile = "~/.ssh/aon.clan";
          AddKeysToAgent = "yes";
        };

        # Keep running sandboxes' credentials current (2026-08-23). A guest's
        # host-identity files — /run/agent.env (cloud LLM keys), the ssh alias
        # config, the git identity — are each written once, at its own boot, so
        # anything df rotates or adds on abhaile afterwards could only reach a
        # running sandbox via a stop/start. `scoite creds --all` re-pushes them
        # into every *running* sandbox; `scoite ssh` does the same on attach,
        # so this timer is really for the headless ones nobody attaches to.
        #
        # No-ops (silently, exit 0) when nothing is running.
        systemd.user.services.scoite-creds = {
          Unit.Description = "Re-push host credentials into running scoite guests";
          Service = {
            Type = "oneshot";
            ExecStart = "${
              inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.scoite
            }/bin/scoite creds --all";
          };
        };

        systemd.user.timers.scoite-creds = {
          Unit.Description = "Periodic scoite guest credential refresh";
          Timer = {
            OnBootSec = "5min";
            OnUnitActiveSec = "10min";
            AccuracySec = "1min";
          };
          Install.WantedBy = [ "timers.target" ];
        };

        # Launch the isolated vault agent (Claude in a microVM that sees only
        # ~/vaults/main) — docs/obsidian.md. Lives here, not in apps.obsidian,
        # so the abbr only exists where `scoite` itself does.
        programs.fish.shellAbbrs.vault-agent = "scoite ~/vaults/main";
      };
  };
}
