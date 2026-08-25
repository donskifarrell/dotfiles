# `omp auth-broker serve` — a persistent background service (nix-ai-tools'
# omp, oh-my-pi) that holds real provider credentials (Anthropic OAuth from
# df's Pro subscription, etc.) in one place and hands them to *other* omp
# instances over HTTP + a bearer token. Built for exactly this: log into a
# provider ONCE, here, and every scoite guest's omp asks the broker for a
# fresh credential instead of storing (and losing, on `scoite stop`'s
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
# omp. That used to be silent (it happened on 2026-08-23 and was visible only
# in the journal); `omp-broker-check` below now watches for it every 15
# minutes and raises a desktop notification. Recover with a fresh
# `omp auth-broker login anthropic` — no restart needed.
#
# `scoite` (pkgs/by-name/scoite) then auto-detects the resulting
# ~/.omp/auth-broker.token and forwards OMP_AUTH_BROKER_URL/_TOKEN into every
# guest it launches; nothing else to configure. That forward is a *boot
# snapshot*, so `scoite creds [<name>|--all]` (also run on every `scoite ssh`,
# and on a 10-minute timer from dev.tools.scoite) re-pushes it into already-
# running guests — see docs/microvm-sandbox.md, "LLM access".
#
# Host-only in practice: this rides roles.dev, and scoite guests run the
# iosta/roles.sandbox.* identity instead, which doesn't include it. (Until
# 2026-07-13 the guest inherited df's full HM identity and so started a
# second, empty broker of its own per boot; verified 2026-08-23 that a guest's
# user units are now only atuin-daemon + tldr-update.) A guest's omp is
# steered at the *host's* broker by the env vars in /run/agent.env.
{ inputs, ... }:
{
  den.aspects.dev.tools.omp-auth-broker = {
    homeManager =
      { pkgs, lib, ... }:
      let
        omp = inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.omp;

        # Watches the two ways the broker can be up and still be useless:
        #
        #   1. a DISABLED credential — a refresh that failed definitively
        #      (`invalid_grant`). Every consumer loses that provider at once,
        #      host and guests alike, and nothing else says so.
        #   2. DUPLICATE credentials for one provider — abhaile once carried a
        #      dead second `anthropic` row that the refresher retried (and
        #      failed) every 60s for hours next to the live one, which is how
        #      the refresh token got rotated out from under the good one in
        #      the first place.
        #
        # Exits non-zero on either, so the failure is also visible in
        # `systemctl --user status omp-broker-check` and not only in a toast
        # that may have been missed.
        brokerCheck = pkgs.writeShellApplication {
          name = "omp-broker-check";
          runtimeInputs = [
            pkgs.curl
            pkgs.jq
            pkgs.libnotify
          ];
          text = ''
            url=''${OMP_BROKER_URL:-http://127.0.0.1:8765}
            token_file=''${OMP_BROKER_TOKEN_FILE:-$HOME/.omp/auth-broker.token}

            notify() {
              # Never fail the check because the desktop bus isn't there (a
              # headless login, a session that has gone away): the journal
              # and the exit status carry the same news.
              notify-send --urgency=critical --app-name=omp "$1" "$2" 2>/dev/null || true
              echo "omp-broker-check: $1 - $2" >&2
            }

            if [ ! -r "$token_file" ]; then
              echo "omp-broker-check: no broker token at $token_file - nothing to check"
              exit 0
            fi
            token=$(cat "$token_file")

            get() { curl -fsS --max-time 10 -H "Authorization: Bearer $token" "$url$1"; }

            if ! snapshot=$(get /v1/snapshot); then
              notify "omp auth-broker unreachable" "No answer from $url - check: systemctl --user status omp-auth-broker"
              exit 1
            fi

            rc=0

            disabled=$(get /v1/credentials/disabled | jq -r '.disabled // [] | length')
            if [ "''${disabled:-0}" -gt 0 ]; then
              which=$(get /v1/credentials/disabled | jq -r '
                [.disabled[] | "\(.provider // "?"): \(.disabledCause // .cause // "disabled")"]
                | join(", ")')
              notify "omp credential disabled" "$which - fix with: omp auth-broker login <provider>"
              rc=1
            fi

            dupes=$(printf '%s' "$snapshot" | jq -r '
              [.credentials[].provider] | group_by(.)
              | map(select(length > 1) | .[0]) | join(", ")')
            if [ -n "$dupes" ]; then
              notify "omp broker has duplicate credentials" "$dupes - the stale row will be retried and can rotate the live one out"
              rc=1
            fi

            [ "$rc" -eq 0 ] && echo "omp-broker-check: ok ($(printf '%s' "$snapshot" | jq -r '.credentials | length') credentials, none disabled)"
            exit "$rc"
          '';
        };
      in
      {
        home.packages = [
          brokerCheck
          # notify-send itself, so a shell (and anything else in this repo
          # that wants to speak up) has it too. Nothing else here provided it.
          pkgs.libnotify
        ];

        systemd.user.services.omp-broker-check = {
          Unit.Description = "Check the omp auth-broker for disabled or duplicate credentials";
          Service = {
            Type = "oneshot";
            ExecStart = lib.getExe brokerCheck;
          };
        };

        systemd.user.timers.omp-broker-check = {
          Unit.Description = "Periodic omp auth-broker credential health check";
          Timer = {
            OnBootSec = "3min";
            OnUnitActiveSec = "15min";
            AccuracySec = "1min";
          };
          Install.WantedBy = [ "timers.target" ];
        };

        systemd.user.services.omp-auth-broker = {
          Unit.Description = "omp (oh-my-pi) auth broker — shared LLM provider credentials";
          Install.WantedBy = [ "default.target" ];
          Service = {
            ExecStart = "${omp}/bin/omp auth-broker serve";
            Restart = "on-failure";
            RestartSec = 5;
          };
        };
      };
  };
}
