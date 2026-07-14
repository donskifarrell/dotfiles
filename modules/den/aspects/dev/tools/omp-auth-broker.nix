# `omp auth-broker serve` — a persistent background service (nix-ai-tools'
# omp, oh-my-pi) that holds real provider credentials (Anthropic OAuth from
# df's Pro subscription, etc.) in one place and hands them to *other* omp
# instances over HTTP + a bearer token. Built for exactly this: log into a
# provider ONCE, here, and every sandvm guest's omp asks the broker for a
# fresh credential instead of storing (and losing, on `sandvm stop`'s
# ephemeral rootfs) its own copy — the broker's own background refresher
# (60s cadence, refreshes anything expiring within 5min) is what actually
# solves "the token expired and the sandbox that could refresh it is gone".
#
# One-time setup (not automated — needs an interactive OAuth browser flow):
#   omp auth-broker login anthropic
#   systemctl --user restart omp-auth-broker
# The restart is required, every time: `login` writes straight to
# ~/.omp/agent/agent.db from its own short-lived process, but the already-
# running server loaded its credential list into memory once at startup and
# has no file-watcher — it can't see the new row until it re-reads the db,
# which only happens on its own boot. Confirmed 2026-07-13: a fresh login
# was invisible to a live broker and to every sandbox already pointed at it
# until `systemctl --user restart omp-auth-broker`; after that, running
# sandboxes picked it up immediately (no guest relaunch needed — they query
# the broker fresh per-request, not once at their own boot).
#
# `sandvm` (pkgs/by-name/sandvm) then auto-detects the resulting
# ~/.omp/auth-broker.token and forwards OMP_AUTH_BROKER_URL/_TOKEN into every
# guest it launches; nothing else to configure.
#
# Runs via roles.dev, so — like `sandvm`/`herdr` themselves — it also starts
# (harmlessly) inside every sandvm guest: a guest's copy binds its own empty,
# disconnected local store, never queried by anything (the guest's omp is
# steered at the *host's* broker via env vars, not its own). Same "known
# quirk" tradeoff as the rest of roles.dev reaching the guest — see
# docs/microvm-sandbox.md.
{ inputs, ... }:
{
  den.aspects.dev.tools.omp-auth-broker = {
    homeManager =
      { pkgs, ... }:
      {
        systemd.user.services.omp-auth-broker = {
          Unit.Description = "omp (oh-my-pi) auth broker — shared LLM provider credentials";
          Install.WantedBy = [ "default.target" ];
          Service = {
            ExecStart = "${
              inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.omp
            }/bin/omp auth-broker serve";
            Restart = "on-failure";
            RestartSec = 5;
          };
        };
      };
  };
}
