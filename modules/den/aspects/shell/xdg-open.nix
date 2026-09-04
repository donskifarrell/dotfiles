# shell.xdg-open — an `xdg-open` for a host that has no GUI to open anything
# with. Guest-only (roles.sandbox.minimal); df's real hosts get the real
# `xdg-open` from xdg-utils via the desktop role.
#
# Why this exists: a sandbox has no desktop, so nothing provides `xdg-open`,
# and any tool that reaches for a browser dies on ENOENT rather than degrading.
# Observed 2026-09-04 with pi's stats-dashboard extension, which starts a local
# server and then hands the URL to `xdg-open` — the failed spawn took the whole
# pi process down (uncaughtException), losing the session. Installing a browser
# to satisfy it would be the wrong trade: the fix is for `xdg-open` to exist and
# to *tell the human the URL* instead of pretending it opened it.
#
# The awkward part is where to tell them. Callers of this shape (pi's is
# verbatim `spawn(cmd, args, { detached: true, stdio: "ignore" })`) give the
# child no stdio and no controlling terminal, so printing to stdout/stderr is
# printing into /dev/null. Hence the write to every pts the invoking user owns:
# an ssh pty is mode 0620 and owned by the session user, so the shim can reach
# the terminal the human is actually sitting at even when its own stdio is
# closed. `$XDG_STATE_HOME/xdg-open.log` catches whatever nobody saw live.
#
# The URL a sandbox tool prints is always loopback *inside the guest*, which is
# not reachable from abhaile: qemu's hostfwd rules point at the user-net guest
# address, not at the guest's 127.0.0.1 (see docs/microvm-sandbox.md,
# Networking). So for a loopback URL the shim also prints the one command that
# does work — an ssh tunnel over the connection the human already has. The
# guest's runtime hostname is set from the INSTANCE credential at boot and is
# exactly the host-side ssh alias (`scoite-bbm`), so it can be quoted directly.
{
  den.aspects.shell.xdg-open.nixos =
    { pkgs, lib, ... }:
    {
      # hiPrio so that pulling xdg-utils in for some other reason (a library
      # that wants `xdg-mime`) doesn't silently restore the crashing behaviour.
      environment.systemPackages = [
        (lib.hiPrio (
          pkgs.writeShellScriptBin "xdg-open" ''
            target=''${1-}
            if [ -z "$target" ]; then
              echo "xdg-open: usage: xdg-open <url|path>" >&2
              exit 1
            fi

            guest=$(${pkgs.coreutils}/bin/cat /proc/sys/kernel/hostname 2>/dev/null || echo sandbox)

            lines=(
              "xdg-open: this is a headless sandbox — nothing was opened."
              "          $target"
            )

            # Loopback URLs are the common case and the only one where there is
            # something useful to say beyond "here it is".
            loopback='^https?://(127\.0\.0\.1|localhost|0\.0\.0\.0|\[::1\])(:([0-9]+))?([/?#]|$)'
            if [[ $target =~ $loopback ]]; then
              port=''${BASH_REMATCH[3]:-80}
              lines+=(
                ""
                "          That address is loopback *in the guest*; the forwarded ports"
                "          on the host do not reach it. From abhaile:"
                ""
                "            ssh -N -L $port:127.0.0.1:$port $guest"
                ""
                "          then open the URL above in a browser there."
              )
            fi

            block=$(printf '%s\n' "''${lines[@]}")

            # stderr first, for the callers that kept theirs...
            printf '%s\n' "$block" >&2

            # ...then every terminal this user owns, for the ones that did not.
            # Skipping our own stderr device keeps the common interactive case
            # from printing twice.
            self=$(${pkgs.coreutils}/bin/readlink /proc/self/fd/2 2>/dev/null || true)
            for dev in /dev/pts/[0-9]*; do
              if [ -w "$dev" ] && [ "$dev" != "$self" ]; then
                printf '\n%s\n' "$block" > "$dev" 2>/dev/null || true
              fi
            done

            state=''${XDG_STATE_HOME:-''${HOME:-/tmp}/.local/state}
            if ${pkgs.coreutils}/bin/mkdir -p "$state" 2>/dev/null; then
              printf '%s\t%s\n' "$(${pkgs.coreutils}/bin/date -Is)" "$target" \
                >> "$state/xdg-open.log" 2>/dev/null || true
            fi

            # Never fail: the entire point is that the caller survives.
            exit 0
          ''
        ))
      ];

      # Tools that consult $BROWSER before falling back to xdg-open (gh, python
      # webbrowser, npm `open`) then land on the same shim instead of their own
      # assorted failure modes.
      environment.sessionVariables.BROWSER = "xdg-open";
    };
}
