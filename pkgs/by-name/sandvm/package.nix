{
  writeShellApplication,
  coreutils,
  gawk,
  iproute2,
  nix,
  procps,
  systemd,
  virtiofsd,
}:
writeShellApplication {
  name = "sandvm";
  meta.description = "Launch a sandboxed per-folder microVM (see docs/microvm-sandbox.md in ~/.dotfiles)";
  runtimeInputs = [
    coreutils
    gawk
    iproute2
    nix
    procps
    systemd
    virtiofsd
  ];
  text = ''
    FLAKE="/home/df/.dotfiles"
    STATE_ROOT="''${XDG_STATE_HOME:-$HOME/.local/state}/sandvm"
    SSH_CONFIG_D="$HOME/.ssh/config.d"
    SSH_CONFIG_FILE="$SSH_CONFIG_D/sandvm"

    usage() {
      cat <<'USAGE'
    Usage:
      sandvm [--port N ...] [--cpu N] [--mem N] [<path>]
          Launch (or re-attach to) a sandboxed microVM for <path> (default:
          current directory). Blocks in the foreground; Ctrl-C or `sandvm stop`
          to stop it. --port forwards an extra host<->guest TCP port (repeatable).

      sandvm stop [<name>]
          Stop a running sandbox (default: the one for the current directory).

      sandvm rm [<name>]
          Stop (if running) and completely delete a sandbox: its state dir
          (assigned port, writable-store-overlay image) and ssh config.d
          entry. Irreversible — devenv/nix state built up in the guest is
          gone; the project folder itself is untouched either way.

      sandvm list
          List known sandboxes, their running state and assigned SSH port.
    USAGE
    }

    # Both drop the "sandvm-" prefix if given (accepts either the raw
    # instance name or the "sandvm-<name>" ssh-alias form users copy from
    # `sandvm`'s own launch banner / `sandvm list`).
    resolve_name() {
      local name=''${1:-$(name_for "$PWD")}
      printf '%s' "''${name#sandvm-}"
    }

    # Drop this instance's "Host sandvm-<name>" block from ssh config.d.
    strip_ssh_block() {
      local name=$1
      [ -f "$SSH_CONFIG_FILE" ] || return 0
      awk -v h="Host sandvm-$name" '
        $0==h {skip=1; next}
        skip && /^Host / {skip=0}
        !skip
      ' "$SSH_CONFIG_FILE" > "$SSH_CONFIG_FILE.tmp"
      mv "$SSH_CONFIG_FILE.tmp" "$SSH_CONFIG_FILE"
    }

    name_for() {
      local real base hash
      real=$(realpath "$1")
      base=$(basename "$real" | tr -c 'a-zA-Z0-9' '-')
      hash=$(printf '%s' "$real" | sha256sum | cut -c1-8)
      printf '%s-%s' "$base" "$hash"
    }

    free_port() {
      local seed=$1 port
      port=$(( 20000 + (16#$(printf '%s' "$seed" | sha256sum | cut -c1-4) % 10000) ))
      while ss -H -tln "sport = :$port" 2>/dev/null | grep -q .; do
        port=$((port + 1))
      done
      echo "$port"
    }

    cmd_list() {
      printf '%-48s %-10s %-8s\n' 'NAME (ssh alias)' STATUS SSH-PORT
      shopt -s nullglob
      for dir in "$STATE_ROOT"/*/; do
        name=$(basename "$dir")
        port=$(cat "$dir/ssh_port" 2>/dev/null || echo -)
        status=stopped
        systemctl --user is-active --quiet "sandvm-$name.scope" 2>/dev/null && status=running
        # Show the "sandvm-<name>" form: that's the literal ssh Host alias
        # and what `sandvm stop` prints in its own hint — showing the bare
        # name here was misleading (ssh has no Host entry for it).
        printf '%-48s %-10s %-8s\n' "sandvm-$name" "$status" "$port"
      done
    }

    cmd_stop() {
      local name; name=$(resolve_name "''${1:-}")
      systemctl --user stop "sandvm-$name.scope" 2>/dev/null || echo "not running: $name"
    }

    cmd_rm() {
      local name; name=$(resolve_name "''${1:-}")
      if [ ! -d "$STATE_ROOT/$name" ]; then
        echo "no such sandbox: $name"
        return 1
      fi
      systemctl --user stop "sandvm-$name.scope" 2>/dev/null || true
      rm -rf "''${STATE_ROOT:?}/''${name:?}"
      strip_ssh_block "$name"
      echo "removed: sandvm-$name"
    }

    cmd_run() {
      local ports=() cpu=4 mem=4096 workdir="$PWD"
      while [ $# -gt 0 ]; do
        case "$1" in
          --port) ports+=("$2"); shift 2 ;;
          --cpu) cpu=$2; shift 2 ;;
          --mem) mem=$2; shift 2 ;;
          -h|--help) usage; exit 0 ;;
          *) workdir=$1; shift ;;
        esac
      done

      workdir=$(realpath "$workdir")
      local name; name=$(name_for "$workdir")
      local state_dir="$STATE_ROOT/$name"
      mkdir -p "$state_dir"

      local ssh_port
      if [ -f "$state_dir/ssh_port" ]; then
        ssh_port=$(cat "$state_dir/ssh_port")
      else
        ssh_port=$(free_port "$name")
        echo "$ssh_port" > "$state_dir/ssh_port"
      fi

      local ports_csv=""
      if [ ''${#ports[@]} -gt 0 ]; then
        ports_csv=$(IFS=,; echo "''${ports[*]}")
      fi

      mkdir -p "$SSH_CONFIG_D"
      touch "$SSH_CONFIG_FILE"
      strip_ssh_block "$name" # idempotent: drop any stale block before re-adding
      {
        echo ""
        echo "Host sandvm-$name"
        echo "  HostName 127.0.0.1"
        echo "  Port $ssh_port"
        echo "  User df"
      } >> "$SSH_CONFIG_FILE"

      # ~/.ssh/config itself is home-manager-managed (a read-only symlink) —
      # modules/den/aspects/core/network/ssh.nix already declares
      # `Include ~/.ssh/config.d/*`, so nothing to do here but write into
      # that directory, which isn't home-manager-owned.

      echo "sandvm '$name' -> $workdir"
      echo "  ssh sandvm-$name"
      echo "  code --remote ssh-remote+sandvm-$name /workspace"
      echo

      # Optional cloud-LLM keys/tokens for the agent harness: KEY=value lines
      # in this file are handed to the guest at launch as a systemd
      # credential (qemu fw_cfg — read at VM start, never in /nix/store) and
      # end up exported in the guest's shells. No file, no credential — the
      # local llama-server provider works either way. Two sources, merged
      # into one per-launch temp file (state_dir, so it doesn't linger
      # outside the instance's own lifecycle):
      #   - ~/.config/sandvm/agent.env: whatever df put there by hand
      #     (plain API keys — OPENAI_API_KEY, XAI_API_KEY, ...).
      #   - the omp auth-broker's token, auto-detected: if
      #     dev.tools.omp-auth-broker's service has been logged into a
      #     provider (`omp auth-broker login anthropic` — one-time, gets df's
      #     Pro subscription via OAuth, not per-token API billing), point the
      #     guest at it so every launch gets a live, auto-refreshed
      #     credential instead of a copy that goes stale the moment the
      #     guest that could refresh it is torn down.
      local agent_env="$state_dir/agent.env"
      : > "$agent_env"
      if [ -f "$HOME/.config/sandvm/agent.env" ]; then
        cat "$HOME/.config/sandvm/agent.env" >> "$agent_env"
      fi
      if [ -f "$HOME/.omp/auth-broker.token" ]; then
        {
          echo "OMP_AUTH_BROKER_URL=http://10.0.2.2:8765"
          echo "OMP_AUTH_BROKER_TOKEN=$(cat "$HOME/.omp/auth-broker.token")"
        } >> "$agent_env"
      fi
      if [ ! -s "$agent_env" ]; then
        rm -f "$agent_env"
        agent_env=""
      fi
      chmod 600 "$agent_env" 2>/dev/null || true

      export MICROVM_WORKDIR="$workdir"
      export MICROVM_NAME="$name"
      export MICROVM_SSH_PORT="$ssh_port"
      export MICROVM_PORTS="$ports_csv"
      export MICROVM_CPU="$cpu"
      export MICROVM_MEM="$mem"
      export MICROVM_AGENT_ENV="$agent_env"

      # Build (not `nix run`) so both the virtiofsd companion and the runner
      # itself come from the exact same store path.
      local runner
      runner=$(nix build --impure --no-link --print-out-paths "$FLAKE#sandvm-guest")

      # Defensive cleanup: a prior crashed/interrupted launch can leave an
      # orphaned virtiofsd holding this instance's socket lock file — systemd
      # scope teardown doesn't reliably reap a backgrounded child if the
      # scope's main process (qemu) exited/errored on its own rather than the
      # scope being stopped via `sandvm stop`. Without this, every relaunch
      # after a crash fails with "Resource temporarily unavailable" forever.
      pkill -f "virtiofsd --socket-path=$name-virtiofs-workspace.sock" 2>/dev/null || true
      rm -f "$state_dir/$name-virtiofs-workspace.sock" "$state_dir/$name-virtiofs-workspace.sock.pid"

      # --working-directory: qemu, virtiofsd's socket, and the guest's
      # writable-store-overlay image (all relative paths) run with CWD = the
      # per-instance state dir, not the project folder — otherwise stray
      # runtime files would land inside /workspace's *host* side, polluting
      # the actual project directory.
      #
      # The workspace share is virtiofs (see microvm-guest.nix for why), which
      # needs a virtiofsd process started first. NOT via microvm.nix's own
      # generated `bin/virtiofsd-run`: that script hardcodes
      # `supervisord user = "root"` (it assumes the host-managed systemd path,
      # where it normally runs as root) and immediately fails with "Can't
      # drop privilege as nonroot user" under this unprivileged imperative
      # setup — so invoke virtiofsd directly instead, matching the socket
      # naming convention (`<name>-virtiofs-<tag>.sock`) qemu itself expects.
      # No systemd Type=notify readiness wiring here either, so poll for the
      # socket before handing off to microvm-run instead of racing it.
      exec systemd-run --user --scope --unit "sandvm-$name" \
        --working-directory="$state_dir" \
        --setenv=MICROVM_WORKDIR="$workdir" \
        --setenv=MICROVM_NAME="$name" \
        --setenv=MICROVM_SSH_PORT="$ssh_port" \
        --setenv=MICROVM_PORTS="$ports_csv" \
        --setenv=MICROVM_CPU="$cpu" \
        --setenv=MICROVM_MEM="$mem" \
        bash -c "
          ${virtiofsd}/bin/virtiofsd --socket-path='$name-virtiofs-workspace.sock' \
            --shared-dir='$workdir' --xattr --cache=auto &
          for _ in \$(seq 300); do
            [ -S '$name-virtiofs-workspace.sock' ] && break
            sleep 0.1
          done
          exec '$runner/bin/microvm-run'
        "
    }

    case "''${1:-}" in
      stop) shift; cmd_stop "$@" ;;
      rm) shift; cmd_rm "$@" ;;
      list) cmd_list ;;
      -h|--help) usage ;;
      *) cmd_run "$@" ;;
    esac
  '';
}
