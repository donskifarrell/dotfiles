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
# No restart needed: the running server re-reads its own store. (It did need
# one on the omp of 2026-07-13, which is why this comment used to insist on
# `systemctl --user restart omp-auth-broker`. Re-verified 2026-08-23 on omp
# 17.4.2 with a throwaway broker on a spare port: a credential written by a
# separate process bumped the live server's snapshot generation immediately,
# no restart, and clients saw it at once.)
#
# When a refresh fails definitively — Anthropic rotates the refresh token on
# every use, so a second holder of the same grant gets `invalid_grant` — the
# broker DISABLES the credential and every consumer, guests included, loses
# omp silently. Nothing surfaces that yet (TODO.md); check by hand with
# `curl -H "Authorization: Bearer $(cat ~/.omp/auth-broker.token)" \
# http://127.0.0.1:8765/v1/credentials/disabled`, and recover with a fresh
# `omp auth-broker login anthropic`.
#
# `sandvm` (pkgs/by-name/sandvm) then auto-detects the resulting
# ~/.omp/auth-broker.token and forwards OMP_AUTH_BROKER_URL/_TOKEN into every
# guest it launches; nothing else to configure. That forward is a *boot
# snapshot*, so `sandvm creds [<name>|--all]` (also run on every `sandvm ssh`,
# and on a 10-minute timer from dev.tools.sandvm) re-pushes it into already-
# running guests — see docs/microvm-sandbox.md, "LLM access".
#
# Host-only in practice: this rides roles.dev, and sandvm guests run the
# iosta/roles.sandbox.* identity instead, which doesn't include it. (Until
# 2026-07-13 the guest inherited df's full HM identity and so started a
# second, empty broker of its own per boot; verified 2026-08-23 that a guest's
# user units are now only atuin-daemon + tldr-update.) A guest's omp is
# steered at the *host's* broker by the env vars in /run/agent.env.
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
