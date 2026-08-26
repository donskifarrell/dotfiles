{
  writeShellApplication,
  symlinkJoin,
  coreutils,
  gawk,
  gnugrep,
  gnutar,
  iproute2,
  nix,
  openssh,
  procps,
  socat,
  systemd,
  virtiofsd,
}:
let
  scoite-unwrapped = writeShellApplication {
    name = "scoite";
    meta.description = "Launch and manage sandboxed microVMs for coding agents (see docs/microvm-sandbox.md in ~/.dotfiles)";
    runtimeInputs = [
      coreutils
      gawk
      gnugrep
      gnutar
      iproute2
      nix
      openssh
      procps
      socat
      systemd
      virtiofsd
    ];
    text = ''
      FLAKE="/home/df/.dotfiles"
      STATE_ROOT="''${XDG_STATE_HOME:-$HOME/.local/state}/scoite"
      SSH_CONFIG_D="$HOME/.ssh/config.d"
      SSH_CONFIG_FILE="$SSH_CONFIG_D/scoite"

      DEFAULT_TYPE=dev

      # Per-type defaults (TASKS.md S18). Measured 2026-08-25 on idle guests:
      # a `dev` sandbox used 513 MiB of RAM, 906 MiB of store overlay and
      # 7 MiB of home; a `minimal` one 624 MiB / 44 KiB / 260 KiB. Memory is a
      # ceiling that qemu allocates lazily (with free-page reporting handing
      # pages back), and both images are sparse, so these are headroom
      # settings, not reservations — which is why `dev` keeps a build-sized
      # ceiling while `minimal`, which has no toolchain to build anything
      # with, gets a small one. `scoite resize` grows disks later; RAM/CPU
      # change on the next start.
      defaults_for() {
        case "$1" in
          minimal)
            DEFAULT_CPU=2
            DEFAULT_MEM=4096
            DEFAULT_DISK=8192
            DEFAULT_HOME_DISK=4096
            ;;
          *)
            DEFAULT_CPU=4
            DEFAULT_MEM=32768
            DEFAULT_DISK=32768
            DEFAULT_HOME_DISK=16384
            ;;
        esac
      }

      # Fixed, not allocated: every instance binds its forwards on an address
      # of its own (see free_addr), so the same port number is free on all of
      # them and there is nothing left to hash around.
      GUEST_SSH_PORT=2222

      # Forwarded on every launch so a guest dev server is viewable from the
      # host with no --port and no restart. 6767 is the paseo daemon
      # (dev.tools.paseo), which every `dev` guest runs. One qemu listening socket each, all
      # on the instance's private address, so a wide net costs ~nothing.
      # Deliberately here and not in the guest module: which of these can
      # actually be bound depends on host state at launch (see
      # effective_ports), which is exactly the kind of per-launch concern the
      # CLI owns and the guest's system closure must never see.
      DEFAULT_DEV_PORTS="$(seq 3000 3009) $(seq 4000 4009) $(seq 5000 5009) \
        $(seq 5173 5182) 6006 6767 $(seq 8000 8009) $(seq 8080 8089) $(seq 9000 9009)"

      usage() {
        cat <<'USAGE'
      Usage:
        scoite new [opts] [<name>]      create a sandbox (and start it)
        scoite start [opts] [<name>]    start an existing sandbox
        scoite stop [<name>]            stop it (state is kept)
        scoite rm [<name>...]           stop + delete it, storage and all
        scoite rename [<name>] <new>    rename it, without a restart
        scoite ssh [<name>] [-- cmd]    ssh in (starts it first if stopped)
        scoite creds [<name>|--all]     re-push host credentials into a running sandbox
        scoite list                     list every sandbox and its state
        scoite resize [<name>] [opts]   grow a sandbox's disks
        scoite expose [<name>] <port>   forward a port into a running sandbox
        scoite expose --lan <port>      also reach it from the LAN (opt-in)
        scoite unexpose [<name>] <port> stop forwarding one
        scoite <path>                   shorthand: new-or-start for a folder

      Names:
        A running guest answers to `<name>.local` (mDNS over the scoitebr0
        bridge) as well as to its private loopback forward address — so
        `http://scoite-myproj.local:5173` works, and `scoite list` prints
        both.

      Viewing a guest's web server:
        Each sandbox owns a loopback address of its own (127.x.y.1, shown by
        `scoite list`), and guest ports map to it 1:1 — a dev server on :5173
        in the guest is http://127.x.y.1:5173 on the host, with no --port and
        no restart. Common dev ports (3000s, 4000s, 5000s, 5173+, 6006, 8000s,
        8080s, 9000s) are forwarded on every launch; `scoite expose` adds any
        other port to a *running* guest. Nothing is reachable off this machine.

      Naming:
        A sandbox is `scoite-<name>`, and that one string is its ssh alias,
        its systemd unit and its hostname inside the VM. `scoite new` in a
        folder proposes `scoite-<folder>` and lets you edit it; `--name`
        skips the prompt. Commands accept either spelling (`mono` or
        `scoite-mono`).

      new/start options:
        --name <name>        name it (default: the workspace folder's name)
        --type minimal|dev   guest flavour (new only, default: dev)
        --workspace <path>   host folder to mount at /workspace (new only;
                             default: a private folder in the instance's state dir)
        --cpu <n>            vCPUs (dev: 4, minimal: 2)
        --mem <MiB>          RAM ceiling, lazily allocated (dev: 32768,
                             minimal: 4096)
        --disk <MiB>         nix store overlay image size, sparse (dev: 32768,
                             minimal: 8192)
        --home-disk <MiB>    /home/iosta image size, sparse (dev: 16384,
                             minimal: 4096)
        --port <n>           also forward this TCP port (repeatable; only
                             needed outside the default set above)
        --ssh, -s            wait for boot, then ssh straight in
        -f, --foreground     block in this terminal instead of detaching
        --fresh              rebuild the runner even if nothing changed

      resize options:
        --disk <MiB>         grow the nix store overlay
        --home-disk <MiB>    grow /home/iosta
      Disks only ever grow; images are sparse, so a size is a ceiling, not a
      cost. A running guest picks the new size up within ~2 minutes (the
      guest's scoite-grow-fs timer), a stopped one on next start.

      Guest types:
        minimal  shell + git + agent harness, with internet access. No dev
                 toolchain at all.
        dev      (default) python, node, headless chromium, compilers, nix-ld,
                 the full TUI shell/git stack, devenv/direnv and herdr. The
                 project's own devenv.nix/flake.nix is pre-built at boot;
                 /home and the nix store overlay persist across stop/start.
      USAGE
      }

      die() { echo "scoite: $*" >&2; exit 1; }

      # An instance is `scoite-<something>` everywhere it is visible: state
      # directory, ssh alias, systemd unit, guest hostname and (from S9) mDNS
      # name are all the same string. Accepts the bare form too, so both
      # `scoite ssh mono` and `scoite ssh scoite-mono` work.
      resolve_name() {
        local name=''${1:-}
        [ -n "$name" ] || { name_for "$PWD"; return; }
        name=$(sanitise_name "$name")
        # Prefer an existing sandbox under either spelling before inventing a
        # new name from the argument.
        if [ -d "$STATE_ROOT/$name" ]; then printf '%s' "$name"; return; fi
        if [ -d "$STATE_ROOT/scoite-$name" ]; then printf '%s' "scoite-$name"; return; fi
        prefixed "$name"
      }

      # `scoite-` exactly once, whichever spelling came in.
      prefixed() {
        case "$1" in
          scoite-*) printf '%s' "$1" ;;
          *) printf 'scoite-%s' "$1" ;;
        esac
      }

      # Lowercase, and only [a-z0-9-] — this string becomes a hostname (DNS
      # label rules) as well as a unit name and a directory.
      sanitise_name() {
        printf '%s' "$1" \
          | tr -d '\n' \
          | tr '[:upper:]' '[:lower:]' \
          | tr -c 'a-z0-9-' '-' \
          | sed -e 's/--*/-/g' -e 's/^-//' -e 's/-$//'
      }

      # The default name for a folder: `scoite-<basename>`. No hash suffix
      # since 2026-08-24 (TASKS.md S6) — a name a human types and reads beats a
      # name that is guaranteed unique, and the two folders that genuinely
      # collide are handled by asking rather than by mangling.
      name_for() {
        local real base
        real=$(realpath "$1")
        base=$(sanitise_name "$(basename "$real")")
        [ -n "$base" ] || base=sandbox
        printf 'scoite-%s' "$base"
      }

      # Offer the derived name for editing on creation. Non-interactive
      # callers (scripts, `--name`, a pipe) get the default with no prompt, so
      # nothing hangs waiting for a tty that isn't there.
      prompt_name() {
        local default=$1 answer
        # stdin + stderr, never stdout: this runs inside a command
        # substitution, so its stdout is a pipe and `[ -t 1 ]` is false even
        # in a fully interactive terminal.
        if [ ! -t 0 ] || [ ! -t 2 ]; then printf '%s' "$default"; return; fi
        printf 'name this sandbox [%s]: ' "$default" >&2
        IFS= read -r answer || answer=""
        answer=$(sanitise_name "$answer")
        if [ -z "$answer" ]; then printf '%s' "$default"; else prefixed "$answer"; fi
      }

      # A stable, unique MAC for the instance's bridge NIC. Locally
      # administered (`02:` prefix = not a real vendor OUI, not multicast) and
      # derived from the name, so a sandbox keeps the same address across
      # restarts — the host's dnsmasq then keeps handing it the same lease,
      # which is what makes a guest's bridge address predictable enough to be
      # worth printing in `scoite list`.
      mac_for() {
        local hash
        hash=$(printf '%s' "$1" | sha256sum)
        printf '02:5c:%s:%s:%s:%s' \
          "''${hash:0:2}" "''${hash:2:2}" "''${hash:4:2}" "''${hash:6:2}"
      }

      # The systemd unit that holds a running instance. It is fixed at
      # creation (config's ID) and deliberately NOT the display name: a
      # running unit cannot be renamed, so `scoite rename` (TASKS.md S7) keeps
      # this stable while everything a human sees moves.
      unit_of() {
        local id
        id=$(sed -n 's/^ID=//p' "$STATE_ROOT/$1/config" 2>/dev/null || true)
        prefixed "''${id:-$1}"
      }

      # Is this address already claimed by a *different* instance?
      addr_taken_by_other() {
        local addr=$1 self=$2 dir other
        shopt -s nullglob
        for dir in "$STATE_ROOT"/*/; do
          if [ "$(basename "$dir")" != "$self" ]; then
            other=$(sed -n 's/^ADDR=//p' "$dir/config" 2>/dev/null || true)
            if [ "$other" = "$addr" ]; then return 0; fi
          fi
        done
        return 1
      }

      # Every instance gets a loopback address of its own. All of 127.0.0.0/8
      # is bound to `lo` on Linux, so any of it is bindable unprivileged with
      # no `ip addr add` and no root. Deterministic from the name (same idiom
      # the ssh port used to use) so an instance keeps its address for life,
      # and 127.<1-254>.<0-255>.1 deliberately avoids 127.0.x.y, where
      # abhaile's own loopback services live (llama-server :8080, harmonia
      # :5000, the omp auth-broker :8765). That separation is the whole point:
      # a guest's :8080 is 127.x.y.1:8080 and collides with nothing, so guest
      # ports can be forwarded 1:1 instead of being renumbered.
      free_addr() {
        local name=$1 hash a b addr _i
        hash=$(printf '%s' "$name" | sha256sum)
        a=$(( 16#''${hash:0:2} % 254 + 1 ))
        b=$(( 16#''${hash:2:2} ))
        for _i in $(seq 256); do
          addr="127.$a.$b.1"
          if ! addr_taken_by_other "$addr" "$name"; then
            echo "$addr"
            return
          fi
          b=$(( (b + 1) % 256 ))
        done
        die "no free loopback address for '$name'"
      }

      is_running() { systemctl --user is-active --quiet "$(unit_of "$1").service" 2>/dev/null; }

      # Host ports qemu would fail to bind on this instance's address. A
      # listener on the wildcard (0.0.0.0, or the dual-stack [::], which also
      # takes the v4 wildcard) occupies every 127.x address, so it takes that
      # port away from every sandbox; one bound to a *specific* address —
      # abhaile's llama-server on 127.0.0.1:8080 — does not, which is the whole
      # reason instances get an address of their own.
      blocked_ports() {
        local addr=$1
        ss -H -tln 2>/dev/null | awk '{print $4}' | awk -v a="$addr" '
          {
            n = split($0, parts, ":")
            port = parts[n]
            host = substr($0, 1, length($0) - length(port) - 1)
            if (host == "0.0.0.0" || host == "*" || host == "[::]" || host == a) print port
          }'
      }

      # The port list this launch will actually forward: the defaults plus the
      # instance's own --port entries, minus anything unbindable. qemu aborts
      # the *entire* VM over a single failed hostfwd rule, so a port that some
      # host process happens to hold must be dropped here rather than allowed
      # to take the sandbox down with it.
      effective_ports() {
        local addr=$1 extras=$2 blocked port out="" skipped=""
        blocked=$(blocked_ports "$addr")
        for port in $DEFAULT_DEV_PORTS $(printf '%s' "$extras" | tr ',' ' '); do
          if [ "$port" = "$GUEST_SSH_PORT" ]; then continue; fi
          if printf '%s\n' "$blocked" | grep -qx "$port"; then
            skipped="''${skipped:+$skipped }$port"
            continue
          fi
          case " $out " in
            *" $port "*) ;;
            *) out="''${out:+$out }$port" ;;
          esac
        done
        if [ -n "$skipped" ]; then
          echo "scoite: not forwarded, held on the host by a wildcard listener: $skipped" >&2
        fi
        printf '%s' "$out" | tr ' ' ','
      }

      # --- per-instance config ------------------------------------------------
      # A plain KEY=value file, sourced on start/resize/ssh so a sandbox keeps
      # the shape it was created with. This is what makes `scoite start <name>`
      # possible at all: nothing about an instance lives in the CLI's argv
      # after `new`.
      load_config() {
        local name=$1
        [ -f "$STATE_ROOT/$name/config" ] || die "no such sandbox: $name (try: scoite list)"
        ADDR="" PORTS="" ID="" LAN_PORTS=""
        # shellcheck disable=SC1090
        . "$STATE_ROOT/$name/config"

        # Migration for instances created before the four tiers became two
        # (2026-08-24): generic/devenv/workstation all collapsed into `dev`,
        # which is a superset of every one of them, so an existing sandbox
        # keeps its home and store overlay and simply boots the new closure.
        case "''${TYPE:-}" in
          generic | devenv | workstation)
            echo "scoite: '$name' type $TYPE -> dev (tiers collapsed)" >&2
            TYPE=dev
            save_config "$name"
            ;;
        esac

        # Migration for instances created before per-instance addresses: give
        # them one, and normalise the ssh port onto it. Their old hashed port
        # would still work, but keeping two schemes alive means every later
        # reader has to handle both.
        if [ -z "$ADDR" ]; then
          ADDR=$(free_addr "$name")
          SSH_PORT=$GUEST_SSH_PORT
          save_config "$name"
          echo "scoite: '$name' moved to $ADDR (ports now map 1:1)" >&2
        fi
      }

      save_config() {
        local dir=$STATE_ROOT/$1
        cat > "$dir/config" <<CFG
      ID=''${ID:-$1}
      TYPE=$TYPE
      WORKSPACE=$WORKSPACE
      CPU=$CPU
      MEM=$MEM
      DISK=$DISK
      HOME_DISK=$HOME_DISK
      PORTS=$PORTS
      LAN_PORTS=''${LAN_PORTS:-}
      SSH_PORT=$SSH_PORT
      ADDR=$ADDR
      CFG
      }

      # --- ssh config.d bookkeeping ------------------------------------------
      strip_ssh_block() {
        local name=$1
        [ -f "$SSH_CONFIG_FILE" ] || return 0
        awk -v h="Host $(prefixed "$name")" '
          $0==h {skip=1; next}
          skip && /^Host / {skip=0}
          !skip
        ' "$SSH_CONFIG_FILE" > "$SSH_CONFIG_FILE.tmp"
        mv "$SSH_CONFIG_FILE.tmp" "$SSH_CONFIG_FILE"
      }

      write_ssh_block() {
        local name=$1 port=$2 addr=$3
        mkdir -p "$SSH_CONFIG_D"
        touch "$SSH_CONFIG_FILE"
        strip_ssh_block "$name"
        # NOTE: no ForwardAgent here, deliberately — this file is Include'd
        # *after* the HM config's `Host *` block (`ForwardAgent no`), and
        # ssh_config is first-match-wins, so it would be silently shadowed.
        # Agent forwarding for scoite-* comes from the HM-rendered block in
        # modules/den/aspects/dev/tools/scoite.nix instead.
        {
          echo ""
          echo "Host $(prefixed "$name")"
          echo "  HostName $addr"
          echo "  Port $port"
          echo "  User iosta"
          echo "  StrictHostKeyChecking accept-new"
        } >> "$SSH_CONFIG_FILE"
      }

      # --- credentials --------------------------------------------------------
      # Everything here reaches the guest as a systemd credential over qemu's
      # fw_cfg: read from the host file at VM start, never copied into the
      # world-readable /nix/store. Absent file -> absent credential; the guest
      # copes with any of them missing.
      collect_credentials() {
        local dir=$STATE_ROOT/$1

        # Cloud LLM keys: hand-maintained ~/.config/scoite/agent.env plus, if
        # the host's omp auth-broker has been logged in, a pointer at it
        # (`omp auth-broker login anthropic`) so the guest gets a live,
        # auto-refreshed credential rather than a copy that goes stale.
        AGENT_ENV=$dir/agent.env
        (umask 077; : > "$AGENT_ENV")
        chmod 600 "$AGENT_ENV"
        if [ -f "$HOME/.config/scoite/agent.env" ]; then
          cat "$HOME/.config/scoite/agent.env" >> "$AGENT_ENV"
        fi
        if [ -f "$HOME/.omp/auth-broker.token" ]; then
          {
            echo "OMP_AUTH_BROKER_URL=http://10.0.2.2:8765"
            echo "OMP_AUTH_BROKER_TOKEN=$(cat "$HOME/.omp/auth-broker.token")"
          } >> "$AGENT_ENV"
        fi
        if [ ! -s "$AGENT_ENV" ]; then rm -f "$AGENT_ENV"; AGENT_ENV=""; fi

        # Git identity (user.name/user.email; a sops secret on the host, no key
        # material). Without it commits in the guest fail with "Author identity
        # unknown".
        GITCONFIG=$HOME/.config/git/gitconfig.local
        [ -r "$GITCONFIG" ] || GITCONFIG=""

        # claude-code's OAuth credential, refreshed on every launch so a
        # long-stopped sandbox still starts with a live token.
        CLAUDE_CREDS=$HOME/.claude/.credentials.json
        [ -r "$CLAUDE_CREDS" ] || CLAUDE_CREDS=""

        # GitHub ssh aliases. df's repos have remotes like
        # git@donskifarrell.github.com:… — an alias that only exists in
        # ~/.ssh/sshconfig.local (a sops secret), so without this a guest
        # can't even resolve the hostname, forwarded agent or not. Each block
        # pins `IdentityFile ~/.ssh/<acct>_gh` + IdentitiesOnly, which is what
        # keeps a multi-account push on the right account.
        #
        # Only the *public* halves go with it: ssh resolves an IdentityFile
        # whose private half is missing but whose .pub is present against the
        # agent, so the guest gets correct per-alias identity selection while
        # every private key stays on the host. A tar because the pub-key set
        # is dynamic and a credential is one file.
        SSH_CONF=""
        if [ -r "$HOME/.ssh/sshconfig.local" ]; then
          local stage=$dir/ssh-conf.d
          rm -rf "$stage"
          mkdir -p "$stage/config.d"
          cp "$HOME/.ssh/sshconfig.local" "$stage/config.d/sshconfig.local"
          local idf
          # `|| true`: no IdentityFile lines at all is a legitimate config,
          # and grep's exit 1 would otherwise trip set -o pipefail.
          for idf in $(grep -iE '^[[:space:]]*IdentityFile[[:space:]]' \
            "$HOME/.ssh/sshconfig.local" | awk '{print $2}' || true); do
            # `~` is literal in ssh_config; expand it the way ssh would.
            idf=''${idf/#\~\//$HOME/}
            if [ -r "$idf.pub" ]; then cp "$idf.pub" "$stage/"; fi
          done
          SSH_CONF=$dir/ssh-conf.tar
          (umask 077; tar -cf "$SSH_CONF" -C "$stage" .)
          chmod 600 "$SSH_CONF"
        fi

        # The *configuration* half of df's omp (TASKS.md S14): config.yml
        # (what `omp config set` writes) and its `config.*.yml` overlays, plus
        # the directories omp discovers agents/skills/rules/prompts/extensions
        # from. Explicitly a list of
        # what to take rather than a list of what to skip: ~/.omp/agent also
        # holds agent.db and models.db (session history, model catalogue),
        # sessions/, logs/ — and the broker token lives one level up. A
        # deny-list would ship any of those the day omp adds one.
        #
        # models.yml is left out on purpose: the guest's own copy points the
        # `local` provider at the SLIRP gateway and is generated from
        # modules/den/aspects/services/_llm-models.nix.
        OMP_CONF=""
        local ompsrc=$HOME/.omp/agent
        if [ -d "$ompsrc" ]; then
          local ompstage
          ompstage=$(mktemp -d)
          local item found=0
          for item in config.yml agents skills skills-vendor rules prompts extensions hooks themes *.md; do
            if [ -e "$ompsrc/$item" ]; then
              cp -a "$ompsrc/$item" "$ompstage/"
              found=1
            fi
          done

          # The overlay configs beside it — `config.sandbox.yml` is the one a
          # guest's omp is actually launched with (roles/sandbox.nix). Globbed
          # separately, and against $ompsrc: a glob in the `for` list above
          # would be expanded relative to the *current* directory instead.
          local overlay
          for overlay in "$ompsrc"/config.*.yml; do
            if [ -e "$overlay" ]; then
              cp -a "$overlay" "$ompstage/"
              found=1
            fi
          done
          if [ "$found" -eq 1 ]; then
            OMP_CONF=$dir/omp-conf.tar
            (umask 077; tar -cf "$OMP_CONF" -C "$ompstage" .)
            chmod 600 "$OMP_CONF"
          fi
          rm -rf "$ompstage"
        fi

        # The instance's own name, for the guest's hostname.
        INSTANCE_FILE=$dir/instance
        printf '%s' "$1" > "$INSTANCE_FILE"
      }

      # --- runner build + cache ----------------------------------------------
      # Every launch used to pay a full impure NixOS eval. The guest's *system
      # closure* no longer depends on any per-instance value (see
      # virtualisation/microvm-guest.nix), so the only thing a relaunch can
      # change is the ~2 kB runner script — and if none of its inputs moved,
      # not even that. Key on the flake's contents (committed + unstaged +
      # untracked) plus every value that reaches the qemu command line.
      flake_fingerprint() {
        {
          git -C "$FLAKE" rev-parse HEAD 2>/dev/null || echo no-git
          git -C "$FLAKE" diff HEAD 2>/dev/null || true
          git -C "$FLAKE" ls-files --others --exclude-standard 2>/dev/null \
            | while read -r f; do sha256sum "$FLAKE/$f" 2>/dev/null || true; done
        } | sha256sum | cut -d' ' -f1
      }

      build_runner() {
        local name=$1 fresh=$2 dir=$STATE_ROOT/$1 key
        key=$(printf '%s\n' "$(flake_fingerprint)" "$TYPE" "$CPU" "$MEM" "$DISK" \
          "$HOME_DISK" "$EFFECTIVE_PORTS" "$SSH_PORT" "$ADDR" "$WORKSPACE" \
          "$(mac_for "$name")" \
          "''${AGENT_ENV:-}" "''${GITCONFIG:-}" "''${CLAUDE_CREDS:-}" \
          "''${SSH_CONF:-}" "''${OMP_CONF:-}" \
          | sha256sum | cut -d' ' -f1)

        if [ "$fresh" -eq 0 ] && [ -L "$dir/runner" ] && [ -e "$dir/runner" ] \
          && [ "$(cat "$dir/runner.key" 2>/dev/null || true)" = "$key" ]; then
          readlink -f "$dir/runner"
          return
        fi

        echo "scoite: building the $TYPE guest runner..." >&2
        # --out-link doubles as a GC root, so the runner and the whole guest
        # closure survive `nix-collect-garbage` for as long as the instance does.
        MICROVM_WORKDIR="$WORKSPACE" \
        MICROVM_SSH_PORT="$SSH_PORT" \
        MICROVM_HOST_ADDR="$ADDR" \
        MICROVM_BR_MAC="$(mac_for "$name")" \
        MICROVM_PORTS="$EFFECTIVE_PORTS" \
        MICROVM_CPU="$CPU" \
        MICROVM_MEM="$MEM" \
        MICROVM_DISK="$DISK" \
        MICROVM_HOME_DISK="$HOME_DISK" \
        MICROVM_AGENT_ENV="''${AGENT_ENV:-}" \
        MICROVM_GITCONFIG="''${GITCONFIG:-}" \
        MICROVM_CLAUDE_CREDS="''${CLAUDE_CREDS:-}" \
        MICROVM_SSH_CONF="''${SSH_CONF:-}" \
        MICROVM_OMP_CONF="''${OMP_CONF:-}" \
        MICROVM_INSTANCE_FILE="$INSTANCE_FILE" \
          nix build --impure --no-warn-dirty --out-link "$dir/runner" \
            "$FLAKE#scoite-guest-$TYPE" >&2
        printf '%s' "$key" > "$dir/runner.key"
        readlink -f "$dir/runner"
      }

      # --- boot ---------------------------------------------------------------
      # A guest authorizes exactly one key, df's passphrase-protected
      # `aon.clan`, so an empty agent means every ssh into every sandbox fails
      # with a bare "Permission denied (publickey)" that says nothing about
      # why. The agent is emptied by any `nixos-rebuild switch` (it restarts
      # home-manager's ssh-agent.service), so this is a routine state, not an
      # exotic one — say so at launch instead of letting it surprise later.
      warn_if_agent_empty() {
        if ! ssh-add -l >/dev/null 2>&1; then
          echo "scoite: the ssh agent holds no keys - 'ssh $(prefixed "$1")' will ask for your key passphrase (or run: ssh-add ~/.ssh/aon.clan)" >&2
        fi
      }

      boot() {
        local name=$1 foreground=$2 fresh=$3
        local dir=$STATE_ROOT/$name runner

        warn_if_agent_empty "$name"

        if is_running "$name"; then echo "scoite: '$name' is already running"; return 0; fi

        collect_credentials "$name"
        # Computed per launch, not persisted: which ports are bindable is host
        # state, and $PORTS stays the small list of what df explicitly asked
        # for. Feeds build_runner's cache key, so a change here rebuilds only
        # the ~2 kB runner script.
        EFFECTIVE_PORTS=$(effective_ports "$ADDR" "$PORTS")
        runner=$(build_runner "$name" "$fresh")

        write_ssh_block "$name" "$SSH_PORT" "$ADDR"

        # Defensive cleanup: a crashed launch can leave an orphaned virtiofsd
        # holding this instance's socket lock, after which every relaunch fails
        # with "Resource temporarily unavailable" forever. The socket path is
        # absolute precisely so this pattern can't match a sibling instance —
        # the guest hostname (and so microvm.nix's socket basename) is now the
        # same string for every sandbox.
        local sock=$dir/sandbox-virtiofs-workspace.sock
        pkill -f "virtiofsd --socket-path=$sock" 2>/dev/null || true
        rm -f "$sock" "$sock.pid"

        # --working-directory: qemu's relative paths (volume images, the QMP
        # socket, the virtiofs socket) resolve inside the instance's state dir
        # rather than polluting the project folder.
        #
        # virtiofsd is started by hand rather than via microvm.nix's generated
        # bin/virtiofsd-run: that script hardcodes `supervisord user = "root"`
        # (it assumes the host-managed systemd path) and fails with "Can't drop
        # privilege as nonroot user" under this unprivileged imperative setup.
        # No Type=notify readiness wiring here either, so poll for the socket
        # rather than racing qemu against it.
        #
        # Plain service unit (not --scope) so it can outlive this terminal;
        # --collect so a crashed unit auto-unloads instead of sitting "failed"
        # and blocking the next launch; --pty is what makes -f block.
        local pty_flag=()
        if [ "$foreground" -eq 1 ]; then pty_flag=(--pty); fi

        systemd-run --user --collect --unit "$(unit_of "$name")" "''${pty_flag[@]}" \
          --working-directory="$dir" \
          bash -c "
            ${virtiofsd}/bin/virtiofsd --socket-path='$sock' \
              --shared-dir='$WORKSPACE' --xattr --cache=auto &
            for _ in \$(seq 300); do
              [ -S '$sock' ] && break
              sleep 0.1
            done
            exec '$runner/bin/microvm-run'
          "
      }

      wait_for_ssh() {
        local name=$1 _i
        for _i in $(seq 120); do
          if ssh -o ConnectTimeout=2 -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
               "$(prefixed "$name")" true 2>/dev/null; then
            return 0
          fi
          is_running "$name" || die "'$name' stopped while booting (journalctl --user -u $(unit_of "$name"))"
          sleep 1
        done
        # The commonest cause by far is an empty host ssh-agent: the guest
        # authorizes df's public key and nothing else, and no private key
        # exists guest-side by design.
        echo "scoite: agent identities: $(ssh-add -l 2>&1 | head -1)" >&2
        die "'$name' did not accept ssh in 120s (journalctl --user -u $(unit_of "$name"); check \`ssh-add -l\`)"
      }

      banner() {
        local name=$1
        echo "scoite '$name' [$TYPE] -> $WORKSPACE"
        echo "  ssh $(prefixed "$name")"
        echo "  code --remote ssh-remote+$(prefixed "$name") /workspace"
        echo "  http://$ADDR:<port>  (guest ports map 1:1; scoite expose $name <port> for others)"
      }

      # --- option parsing -----------------------------------------------------
      # Shared by new/start/resize; each caller decides which results it honours.
      OPT_NAME="" OPT_SSH=0 OPT_FG=0 OPT_FRESH=0
      OPT_TYPE="" OPT_WORKSPACE="" OPT_CPU="" OPT_MEM="" OPT_DISK="" OPT_HOME_DISK=""
      OPT_PORTS=()
      parse_opts() {
        OPT_NAME="" OPT_SSH=0 OPT_FG=0 OPT_FRESH=0
        OPT_TYPE="" OPT_WORKSPACE="" OPT_CPU="" OPT_MEM="" OPT_DISK="" OPT_HOME_DISK=""
        OPT_PORTS=()
        while [ $# -gt 0 ]; do
          case "$1" in
            --name) OPT_NAME=$2; shift 2 ;;
            --type) OPT_TYPE=$2; shift 2 ;;
            --workspace) OPT_WORKSPACE=$2; shift 2 ;;
            --cpu) OPT_CPU=$2; shift 2 ;;
            --mem) OPT_MEM=$2; shift 2 ;;
            --disk) OPT_DISK=$2; shift 2 ;;
            --home-disk) OPT_HOME_DISK=$2; shift 2 ;;
            --port) OPT_PORTS+=("$2"); shift 2 ;;
            -s|--ssh) OPT_SSH=1; shift ;;
            -f|--foreground) OPT_FG=1; shift ;;
            --fresh) OPT_FRESH=1; shift ;;
            -h|--help) usage; exit 0 ;;
            -*) die "unknown option: $1" ;;
            *) OPT_NAME=$1; shift ;;
          esac
        done
      }

      valid_type() {
        case "$1" in
          minimal|dev) return 0 ;;
          *) die "unknown --type '$1' (minimal|dev)" ;;
        esac
      }

      # --- commands -----------------------------------------------------------
      cmd_new() {
        parse_opts "$@"
        local name=''${OPT_NAME:-}

        TYPE=''${OPT_TYPE:-$DEFAULT_TYPE}
        valid_type "$TYPE"

        # A sandbox does not need a host folder. Without --workspace it gets a
        # private one inside its own state dir, so /workspace always exists and
        # is always writable — and is still visible from the host for handing
        # files in and out.
        WORKSPACE=""
        if [ -n "$OPT_WORKSPACE" ]; then
          WORKSPACE=$(realpath "$OPT_WORKSPACE")
          [ -d "$WORKSPACE" ] || die "no such directory: $WORKSPACE"
          if [ -n "$name" ]; then
            name=$(prefixed "$(sanitise_name "$name")")
          else
            # Derived from the folder, then offered for editing: the folder
            # name is right most of the time, and the one time it isn't is
            # the moment the sandbox is created, not later.
            name=$(prompt_name "$(name_for "$WORKSPACE")")
          fi
        else
          [ -n "$name" ] || die "give a name, or --workspace <path> to derive one"
          name=$(prefixed "$(sanitise_name "$name")")
        fi

        if [ -e "$STATE_ROOT/$name/config" ]; then
          # Two folders with the same basename are the expected collision
          # (~/dev/mono and ~/work/mono). Refuse rather than pick for them:
          # the name is the ssh alias and the DNS name, so silently reusing
          # one sandbox for two projects is the worst possible outcome.
          local taken
          taken=$(sed -n 's/^WORKSPACE=//p' "$STATE_ROOT/$name/config" 2>/dev/null || true)
          if [ "$taken" = "$WORKSPACE" ]; then
            die "'$name' already exists for this folder (scoite start $name)"
          fi
          die "'$name' is taken by $taken - pick another with: scoite new --name <name> --workspace $WORKSPACE"
        fi

        # Immutable for the instance's life: the systemd unit is named after
        # it, and a running unit cannot be renamed (see unit_of / S7).
        ID=$name

        local dir=$STATE_ROOT/$name
        mkdir -p "$dir"
        if [ -z "$WORKSPACE" ]; then
          WORKSPACE=$dir/workspace
          mkdir -p "$WORKSPACE"
        fi

        defaults_for "$TYPE"
        CPU=''${OPT_CPU:-$DEFAULT_CPU}
        MEM=''${OPT_MEM:-$DEFAULT_MEM}
        DISK=''${OPT_DISK:-$DEFAULT_DISK}
        HOME_DISK=''${OPT_HOME_DISK:-$DEFAULT_HOME_DISK}
        PORTS=$(IFS=,; echo "''${OPT_PORTS[*]:-}")
        SSH_PORT=$GUEST_SSH_PORT
        ADDR=$(free_addr "$name")
        save_config "$name"

        banner "$name"
        boot "$name" "$OPT_FG" "$OPT_FRESH"
        if [ "$OPT_SSH" -eq 1 ]; then wait_for_ssh "$name"; exec ssh "$(prefixed "$name")"; fi
      }

      cmd_start() {
        parse_opts "$@"
        local name; name=$(resolve_name "''${OPT_NAME:-}")
        load_config "$name"

        # --type/--workspace are fixed at creation; the rest can be retuned on
        # any start and are remembered from then on.
        if [ -n "$OPT_TYPE" ]; then die "--type is set at creation; make a new sandbox instead"; fi
        if [ -n "$OPT_WORKSPACE" ]; then die "--workspace is set at creation; make a new sandbox instead"; fi
        if [ -n "$OPT_CPU" ]; then CPU=$OPT_CPU; fi
        if [ -n "$OPT_MEM" ]; then MEM=$OPT_MEM; fi
        if [ ''${#OPT_PORTS[@]} -gt 0 ]; then PORTS=$(IFS=,; echo "''${OPT_PORTS[*]}"); fi
        save_config "$name"

        banner "$name"
        boot "$name" "$OPT_FG" "$OPT_FRESH"
        if [ -n "''${LAN_PORTS:-}" ]; then wait_for_ssh "$name"; lan_reapply "$name"; fi
        if [ "$OPT_SSH" -eq 1 ]; then wait_for_ssh "$name"; exec ssh "$(prefixed "$name")"; fi
      }

      cmd_stop() {
        local name; name=$(resolve_name "''${1:-}")
        # LAN forwards point at an address the guest is about to stop
        # answering on; leaving them installed would silently DNAT traffic
        # into a black hole (or, after a lease change, into another sandbox).
        ( load_config "$name" 2>/dev/null && lan_teardown ) || true
        systemctl --user stop "$(unit_of "$name").service" 2>/dev/null || echo "not running: $name"
      }

      cmd_rm() {
        local arg name dir
        if [ $# -eq 0 ]; then set -- "$(resolve_name "")"; fi
        for arg in "$@"; do
          name=$(resolve_name "$arg")
          dir=$STATE_ROOT/$name
          [ -d "$dir" ] || { echo "no such sandbox: $name"; continue; }
          ( load_config "$name" 2>/dev/null && lan_teardown ) || true
          systemctl --user stop "$(unit_of "$name").service" 2>/dev/null || true
          # The runner out-link is a GC root; dropping the directory drops it,
          # so the guest closure becomes collectable again.
          rm -rf "''${STATE_ROOT:?}/''${name:?}"
          strip_ssh_block "$name"
          echo "removed: $name"
        done
      }

      # --- rename -------------------------------------------------------------
      # Renames a sandbox *without* restarting it. What moves and what does
      # not:
      #   moves   the state directory, the ssh alias block, the guest's
      #           hostname (and with it its mDNS `<name>.local`), and the
      #           config's own idea of its name.
      #   stays   the systemd unit (config's ID — a running unit cannot be
      #           renamed, and killing it would kill the guest), the loopback
      #           forward address, the SSH host key, the MAC and therefore the
      #           bridge lease.
      # Renaming the directory under a live qemu is safe: its cwd and open
      # files follow the inode, and every path the CLI re-derives (QMP socket,
      # volumes, virtiofs socket) is inside the directory that just moved.
      cmd_rename() {
        local old new running=0
        case $# in
          1) old=$(resolve_name ""); new=$1 ;;
          2) old=$(resolve_name "$1"); new=$2 ;;
          *) die "usage: scoite rename [<name>] <new-name>" ;;
        esac
        new=$(prefixed "$(sanitise_name "$new")")

        [ -d "$STATE_ROOT/$old" ] || die "no such sandbox: $old (try: scoite list)"
        [ "$old" != "$new" ] || die "'$old' is already called that"
        [ ! -e "$STATE_ROOT/$new" ] || die "'$new' already exists"

        load_config "$old"
        if is_running "$old"; then running=1; fi

        mv "$STATE_ROOT/$old" "$STATE_ROOT/$new"

        # A sandbox created without --workspace keeps its project folder
        # inside its own state dir, so that path just moved too.
        case "$WORKSPACE" in
          "$STATE_ROOT/$old"/*)
            WORKSPACE="$STATE_ROOT/$new/''${WORKSPACE#"$STATE_ROOT/$old/"}"
            ;;
        esac
        save_config "$new"

        strip_ssh_block "$old"
        write_ssh_block "$new" "$SSH_PORT" "$ADDR"

        if [ "$running" -eq 1 ]; then
          # `hostname`, not `hostnamectl`: the guest has a *static* hostname
          # ("sandbox", baked into the shared closure and read-only in
          # /etc/hostname), and systemd deliberately ignores a transient
          # hostname whenever a static one exists — hostnamectl says as much
          # and does nothing. A raw sethostname() is also what
          # scoite-hostname.service does at boot. Restarting resolved is the
          # other half: it caches the name it announces over mDNS and a
          # sethostname() behind its back sends it no dbus signal, so without
          # this the guest keeps answering to its old `.local` name.
          ssh -o BatchMode=yes -o ConnectTimeout=10 "$(prefixed "$new")" -- \
            "sudo hostname '$new' && sudo systemctl restart systemd-resolved" \
            || echo "scoite: could not set the guest's hostname - it will pick the new name up on next start" >&2
        fi

        echo "renamed: $old -> $new"
        if [ "$running" -eq 1 ]; then
          echo "  ssh $(prefixed "$new")   http://$new.local:<port>"
          echo "  (systemd unit stays $(unit_of "$new").service until it next stops)"
        fi
      }

      # --- live credential refresh -------------------------------------------
      # /run/agent.env is written once, at boot, from a snapshot of the host's
      # omp broker bearer token. Everything else on that path is already live —
      # the broker re-reads its own store when df logs a provider back in, and
      # a guest's omp queries the broker per request rather than caching a
      # copy — so the boot snapshot is the one piece that can go stale: a
      # sandbox launched before `omp auth-broker login`, or still running when
      # the bearer token is rotated, has no way back to a working credential
      # short of a stop/start. This re-stages agent.env and writes it into a
      # running guest instead.
      #
      # `-o ForwardAgent=no` is load-bearing, not tidiness: the guest's login
      # shell re-points ~/.ssh/agent.sock at whatever connection it sees, and a
      # scripted connection's forwarded socket dies when that connection does —
      # a push that forwarded the agent would leave long-lived herdr panes
      # holding a dead socket until the next real login. With no agent
      # forwarded, the guest-side re-point is skipped entirely.
      # Stream a staged host file into the guest and run a guest-side
      # installer on it. `sudo -n`: iosta is wheel with passwordless sudo in
      # the sandbox, and the installers have to write outside its home.
      # ForwardAgent=no is load-bearing, not tidiness (see the note above).
      push_file() {
        local name=$1 src=$2 remote_cmd=$3
        [ -n "$src" ] && [ -f "$src" ] || return 0
        ssh -o ForwardAgent=no -o BatchMode=yes -o ConnectTimeout=5 \
          -o StrictHostKeyChecking=accept-new "$(prefixed "$name")" -- \
          "sudo -n sh -c '$remote_cmd'" < "$src"
      }

      push_credentials() {
        local name=$1
        is_running "$name" || return 0
        collect_credentials "$name"

        # The broker URL + bearer token.
        push_file "$name" "''${AGENT_ENV:-}" \
          'cat > /run/agent.env.new && chown iosta:users /run/agent.env.new && chmod 600 /run/agent.env.new && mv /run/agent.env.new /run/agent.env'

        # df's ssh aliases and the public halves of the keys they name
        # (TASKS.md S13). A `Host` block added on abhaile after a sandbox
        # booted used to need a stop/start to reach it; now it lands on the
        # next `scoite creds`, `scoite ssh`, or 10-minute timer tick. Private
        # keys still never enter a guest — auth is the forwarded agent.
        push_file "$name" "''${SSH_CONF:-}" \
          'cat > /run/ssh-conf.tar && scoite-install-ssh-conf /run/ssh-conf.tar; rm -f /run/ssh-conf.tar'

        # git identity (user.name/email and whatever else lives in df's
        # gitconfig.local, itself a sops secret).
        push_file "$name" "''${GITCONFIG:-}" \
          'cat > /run/gitconfig.local && scoite-install-gitconfig /run/gitconfig.local; rm -f /run/gitconfig.local'

        # df's omp settings/agents/skills/rules (TASKS.md S14).
        push_file "$name" "''${OMP_CONF:-}" \
          'cat > /run/omp-conf.tar && scoite-install-omp-conf /run/omp-conf.tar; rm -f /run/omp-conf.tar'
      }

      # Only new shells see a refreshed /run/agent.env (fish exports it at
      # shell start), which is enough for what it's for: `omp` reads the broker
      # token when it starts, so the next command picks it up. A pane that was
      # already open keeps the stale value.
      cmd_creds() {
        local name rc=0
        if [ "''${1:-}" = "--all" ]; then
          shopt -s nullglob
          for dir in "$STATE_ROOT"/*/; do
            name=$(basename "$dir")
            is_running "$name" || continue
            if push_credentials "$name"; then
              echo "scoite: credentials refreshed in '$name'"
            else
              echo "scoite: could not refresh credentials in '$name'" >&2
              rc=1
            fi
          done
          return $rc
        fi
        name=$(resolve_name "''${1:-}")
        is_running "$name" || die "'$name' is not running"
        push_credentials "$name" || die "could not refresh credentials in '$name'"
        echo "scoite: credentials refreshed in '$name'"
      }

      cmd_ssh() {
        # Warn before the connection, not after it fails: an empty agent is
        # the commonest reason a sandbox refuses a key (see
        # warn_if_agent_empty).

        local name; name=$(resolve_name "''${1:-}")
        shift || true
        if [ "''${1:-}" = "--" ]; then shift; fi
        load_config "$name"
        warn_if_agent_empty "$name"
        if ! is_running "$name"; then
          banner "$name"
          boot "$name" 0 0
        fi
        wait_for_ssh "$name"
        # Best-effort, silent: an attach is the natural moment to hand a
        # long-running sandbox whatever the host's credentials look like now.
        push_credentials "$name" || true
        if [ $# -gt 0 ]; then
          exec ssh "$(prefixed "$name")" -- "$@"
        else
          exec ssh "$(prefixed "$name")"
        fi
      }

      # The guest's address on the scoitebr0 bridge, or "-" if it has none
      # (stopped, or booted before the bridge NIC existed). mDNS first — that
      # is the same path a browser or ssh takes, so an answer here means the
      # DNS name in the next column genuinely works — with the host's dnsmasq
      # lease file as the fallback for the moment between DHCP and the first
      # mDNS announcement.
      bridge_ip() {
        local name=$1 ip
        ip=$(getent ahostsv4 "$name.local" 2>/dev/null | awk 'NR==1{print $1}')
        if [ -z "$ip" ]; then
          ip=$(awk -v m="$(mac_for "$name")" '$2 == m {print $3}' \
            /var/lib/scoite/dnsmasq.leases 2>/dev/null | tail -1)
        fi
        printf '%s' "''${ip:--}"
      }

      cmd_list() {
        local fmt='%-24s %-8s %-8s %-26s %-13s %-13s %-9s %-7s %s\n'
        # shellcheck disable=SC2059
        printf "$fmt" NAME TYPE STATUS DNS IP FORWARD LAN ON-DISK WORKSPACE
        shopt -s nullglob
        for dir in "$STATE_ROOT"/*/; do
          local name status used dns ip
          name=$(basename "$dir")
          status=stopped
          dns="-" ip="-"
          if is_running "$name"; then
            status=running
            dns="$(prefixed "$name").local"
            ip=$(bridge_ip "$(prefixed "$name")")
          fi
          used=$(du -sh "$dir" 2>/dev/null | cut -f1)
          if [ -f "$dir/config" ]; then
            ( # subshell: don't leak one instance's config into the next
              # shellcheck disable=SC1091
              . "$dir/config"
              # shellcheck disable=SC2059
              printf "$fmt" \
                "$name" "$TYPE" "$status" "$dns" "$ip" \
                "''${ADDR:-(on next start)}" "''${LAN_PORTS:--}" "$used" "$WORKSPACE"
            )
          else
            # A state dir from before the two-type rework — `scoite rm` it.
            # shellcheck disable=SC2059
            printf "$fmt" "$name" "legacy" "$status" "-" "-" "-" "-" "$used" "-"
          fi
        done
      }

      # --- resize -------------------------------------------------------------
      # Images are sparse: growing one costs nothing until the guest writes into
      # it. Grow the backing file, tell a running qemu about it over QMP, and
      # let the guest's scoite-grow-fs timer stretch the filesystem to match.
      # Run a qemu *human monitor* command over the QMP socket and echo what it
      # printed (empty output = success). hostfwd_add/hostfwd_remove have no
      # QMP equivalent — they exist only in HMP — and this is what lets a port
      # be forwarded into an already-running guest instead of costing a
      # stop/start cycle.
      qmp_hmp() {
        local sock=$1 cmd=$2
        printf '%s\n%s\n' \
          '{"execute":"qmp_capabilities"}' \
          "{\"execute\":\"human-monitor-command\",\"arguments\":{\"command-line\":\"$cmd\"}}" \
          | socat -t 2 - "UNIX-CONNECT:$sock" 2>/dev/null \
          | grep -o '"return": *"[^"]*"' | tail -1 \
          | sed 's/.*"return": *"//; s/"$//; s/\\r\\n$//' || true
      }

      qmp() {
        local sock=$1 device=$2 bytes=$3
        printf '%s\n%s\n' \
          '{"execute":"qmp_capabilities"}' \
          "{\"execute\":\"block_resize\",\"arguments\":{\"device\":\"$device\",\"size\":$bytes}}" \
          | socat - "UNIX-CONNECT:$sock" >/dev/null 2>&1 || return 1
      }

      grow_image() {
        local dir=$1 image=$2 device=$3 new_mib=$4 running=$5
        local path=$dir/$image cur_mib=0
        if [ -f "$path" ]; then
          cur_mib=$(( $(stat -c %s "$path") / 1048576 ))
        fi
        if [ "$new_mib" -le "$cur_mib" ]; then
          echo "  $image: already ''${cur_mib}M (disks only grow) - skipped"
          return 0
        fi
        truncate -s "''${new_mib}M" "$path"
        echo "  $image: ''${cur_mib}M -> ''${new_mib}M"
        if [ "$running" -eq 1 ]; then
          if qmp "$dir/sandbox.sock" "$device" "$(( new_mib * 1048576 ))"; then
            echo "    live-resized $device; the guest grows the filesystem within ~2min"
          else
            echo "    could not reach qemu's QMP socket - takes effect on next start"
          fi
        fi
      }

      cmd_resize() {
        parse_opts "$@"
        local name; name=$(resolve_name "''${OPT_NAME:-}")
        load_config "$name"
        [ -n "$OPT_DISK$OPT_HOME_DISK" ] || die "give --disk <MiB> and/or --home-disk <MiB>"

        local dir=$STATE_ROOT/$name running=0
        if is_running "$name"; then running=1; fi

        if [ -n "$OPT_DISK" ]; then
          grow_image "$dir" nix-store-overlay.img vda "$OPT_DISK" "$running"
          if [ "$OPT_DISK" -gt "$DISK" ]; then DISK=$OPT_DISK; fi
        fi
        if [ -n "$OPT_HOME_DISK" ]; then
          grow_image "$dir" home.img vdb "$OPT_HOME_DISK" "$running"
          if [ "$OPT_HOME_DISK" -gt "$HOME_DISK" ]; then HOME_DISK=$OPT_HOME_DISK; fi
        fi
        save_config "$name"
      }

      # --- expose -------------------------------------------------------------
      # A wide set of common dev ports is forwarded on every launch (see
      # defaultDevPorts in modules/den/aspects/virtualisation/microvm-guest.nix),
      # so this is only needed for a port outside that set. It takes effect on a
      # running guest immediately — qemu grows a listening socket on the
      # instance's own address — and is persisted so a restart keeps it.
      is_port() { printf '%s' "$1" | grep -qE '^[0-9]+$'; }

      # `expose 5173` (name from $PWD) as well as `expose <name> 5173`.
      expose_args() {
        EXPOSE_LAN=0 EXPOSE_LAN_PORT=""
        local rest=()
        while [ $# -gt 0 ]; do
          case "$1" in
            --lan) EXPOSE_LAN=1; shift ;;
            --lan-port) EXPOSE_LAN=1; EXPOSE_LAN_PORT=$2; shift 2 ;;
            *) rest+=("$1"); shift ;;
          esac
        done
        set -- "''${rest[@]:-}"

        if [ $# -gt 0 ] && is_port "$1"; then
          EXPOSE_NAME=$(resolve_name "")
        else
          EXPOSE_NAME=$(resolve_name "''${1:-}")
          shift || true
        fi
        EXPOSE_PORTS=("$@")
      }

      # --- LAN exposure -------------------------------------------------------
      # Everything above this line stays on the host: qemu's forwards bind
      # 127.x.y.1. This is the one door to the rest of the network, and it is
      # opened one port at a time, per instance, by hand.
      #
      # Shape: a DNAT on abhaile's LAN interface to the guest's bridge address,
      # installed by the root-side `scoite-lan` helper
      # (virtualisation/microvm-host.nix). The URL is abhaile's own name — a
      # guest's `<name>.local` is published on the sandbox bridge only, and
      # abhaile's LAN is wifi, where L2-bridging a guest onto it is not
      # possible.
      lan_add() {
        local name=$1 gport=$2 lport=$3 gip
        gip=$(bridge_ip "$(prefixed "$name")")
        [ "$gip" != "-" ] || die "'$name' has no bridge address yet (is it running?)"
        sudo scoite-lan add "$gip" "$gport" "$lport" >/dev/null \
          || die "could not install the LAN forward for $lport"
      }

      lan_del() { sudo scoite-lan del "$1" >/dev/null 2>&1 || true; }

      # LAN_PORTS in the instance config: "guest:lan,guest:lan,…".
      lan_record() {
        local gport=$1 lport=$2
        case ",''${LAN_PORTS:-}," in
          *",$gport:$lport,"*) ;;
          *) LAN_PORTS=''${LAN_PORTS:+$LAN_PORTS,}$gport:$lport ;;
        esac
      }

      lan_forget() {
        local gport=$1 out="" e
        for e in $(printf '%s' "''${LAN_PORTS:-}" | tr ',' ' '); do
          case "$e" in
            "$gport":*) ;;
            *) out=''${out:+$out,}$e ;;
          esac
        done
        LAN_PORTS=$out
      }

      # Is this LAN port already claimed — by another sandbox, or by anything
      # else this host forwards? All exposures land on one LAN address, so two
      # sandboxes cannot both own :5173 there.
      lan_port_taken() {
        sudo scoite-lan list 2>/dev/null | grep -q "^scoite:$1:"
      }

      # Re-install every recorded forward. The guest's bridge address is
      # lease-stable (the MAC is derived from the name), but the iptables rules
      # live in kernel state that a reboot — or a stop/start — clears.
      lan_reapply() {
        local name=$1 e gport lport
        [ -n "''${LAN_PORTS:-}" ] || return 0
        for e in $(printf '%s' "$LAN_PORTS" | tr ',' ' '); do
          gport=''${e%%:*}; lport=''${e##*:}
          lan_del "$lport"
          lan_add "$name" "$gport" "$lport" || true
        done
      }

      lan_teardown() {
        local e lport
        for e in $(printf '%s' "''${LAN_PORTS:-}" | tr ',' ' '); do
          lport=''${e##*:}
          lan_del "$lport"
        done
      }

      cmd_expose() {
        local port out dir
        expose_args "$@"
        [ ''${#EXPOSE_PORTS[@]} -gt 0 ] || die "usage: scoite expose [<name>] [--lan [--lan-port <n>]] <port>..."
        load_config "$EXPOSE_NAME"
        dir=$STATE_ROOT/$EXPOSE_NAME

        if [ "$EXPOSE_LAN" -eq 1 ]; then
          is_running "$EXPOSE_NAME" || die "'$EXPOSE_NAME' must be running to expose it to the LAN"
          [ ''${#EXPOSE_PORTS[@]} -eq 1 ] || die "--lan takes one port at a time"
          local gport=''${EXPOSE_PORTS[0]} lport
          is_port "$gport" || die "not a port number: $gport"
          lport=''${EXPOSE_LAN_PORT:-$gport}
          is_port "$lport" || die "not a port number: $lport"

          if lan_port_taken "$lport"; then
            die "LAN port $lport is already forwarded to another sandbox - pick another with --lan-port <n>"
          fi

          # 6767 is the paseo daemon, which ships with no password
          # (authRequired: false) — anyone who reaches it drives the agent.
          if [ "$gport" = 6767 ]; then
            echo "scoite: WARNING: paseo has no password by default - set one (paseo daemon set-password) before trusting this" >&2
          fi

          lan_add "$EXPOSE_NAME" "$gport" "$lport"
          lan_record "$gport" "$lport"
          save_config "$EXPOSE_NAME"
          echo "  http://$(hostname).local:$lport  (LAN -> $EXPOSE_NAME:$gport)"
          return 0
        fi

        for port in "''${EXPOSE_PORTS[@]}"; do
          is_port "$port" || die "not a port number: $port"

          # Already listening (almost always: it's in the default set) — adding
          # it again just makes qemu fail to bind.
          if ss -H -tln "src = $ADDR:$port" 2>/dev/null | grep -q .; then
            echo "  http://$ADDR:$port (already forwarded)"
            continue
          fi
          if is_running "$EXPOSE_NAME" && printf '%s\n' "$(blocked_ports "$ADDR")" | grep -qx "$port"; then
            die "port $port is held on the host by a wildcard listener - free it first"
          fi

          case ",$PORTS," in
            *",$port,"*) ;;
            *) PORTS=''${PORTS:+$PORTS,}$port ;;
          esac

          if is_running "$EXPOSE_NAME"; then
            out=$(qmp_hmp "$dir/sandbox.sock" "hostfwd_add usernet0 tcp:$ADDR:$port-:$port")
            if [ -n "$out" ]; then
              echo "scoite: $port: $out" >&2
            else
              echo "  http://$ADDR:$port"
            fi
          else
            echo "  http://$ADDR:$port (on next start)"
          fi
        done
        save_config "$EXPOSE_NAME"
      }

      cmd_unexpose() {
        local port out dir
        expose_args "$@"
        [ ''${#EXPOSE_PORTS[@]} -gt 0 ] || die "usage: scoite unexpose [<name>] [--lan] <port>..."
        load_config "$EXPOSE_NAME"
        dir=$STATE_ROOT/$EXPOSE_NAME

        if [ "$EXPOSE_LAN" -eq 1 ]; then
          local gport e lport
          for gport in "''${EXPOSE_PORTS[@]}"; do
            is_port "$gport" || die "not a port number: $gport"
            for e in $(printf '%s' "''${LAN_PORTS:-}" | tr ',' ' '); do
              case "$e" in
                "$gport":*)
                  lport=''${e##*:}
                  lan_del "$lport"
                  echo "  closed LAN :$lport -> $EXPOSE_NAME:$gport"
                  ;;
              esac
            done
            lan_forget "$gport"
          done
          save_config "$EXPOSE_NAME"
          return 0
        fi

        for port in "''${EXPOSE_PORTS[@]}"; do
          is_port "$port" || die "not a port number: $port"

          local was_extra=0
          case ",$PORTS," in
            *",$port,"*) was_extra=1 ;;
          esac
          PORTS=$(printf '%s' "$PORTS" | tr ',' '\n' | grep -vx "$port" | paste -sd, - || true)

          if is_running "$EXPOSE_NAME"; then
            # hostfwd_remove reports success with a message ("...removed"),
            # unlike hostfwd_add which is silent on success.
            out=$(qmp_hmp "$dir/sandbox.sock" "hostfwd_remove usernet0 tcp:$ADDR:$port")
            case "$out" in
              "" | *removed*) ;;
              *) echo "scoite: $port: $out" >&2 ;;
            esac
          fi
          if [ "$was_extra" -eq 0 ]; then
            echo "scoite: $port is in the default forwarded set - closed for this run, back on next start" >&2
          fi
        done
        save_config "$EXPOSE_NAME"
      }

      # --- dispatch -----------------------------------------------------------
      case "''${1:-}" in
        new) shift; cmd_new "$@" ;;
        start|up) shift; cmd_start "$@" ;;
        stop) shift; cmd_stop "$@" ;;
        rm|delete) shift; cmd_rm "$@" ;;
        rename|mv) shift; cmd_rename "$@" ;;
        ssh) shift; cmd_ssh "$@" ;;
        creds) shift; cmd_creds "$@" ;;
        list|ls) cmd_list ;;
        resize) shift; cmd_resize "$@" ;;
        expose) shift; cmd_expose "$@" ;;
        unexpose) shift; cmd_unexpose "$@" ;;
        -h|--help|help) usage ;;
        "")
          # Bare `scoite` in a project folder: new-or-start for $PWD.
          name=$(name_for "$PWD")
          if [ -f "$STATE_ROOT/$name/config" ]; then cmd_start "$name"; else cmd_new --workspace "$PWD"; fi
          ;;
        *)
          # `scoite <path>` shorthand (what the vault-agent abbr uses).
          [ -d "$1" ] || die "unknown command '$1' (scoite --help)"
          path=$1; shift
          name=$(name_for "$path")
          if [ -f "$STATE_ROOT/$name/config" ]; then
            cmd_start "$name" "$@"
          else
            cmd_new --workspace "$path" "$@"
          fi
          ;;
      esac
    '';
  };
in
symlinkJoin {
  name = "scoite";
  paths = [ scoite-unwrapped ];
  # Fish auto-discovers vendor_completions.d from every package in the profile
  # (see modules/den/aspects/shell/fish.nix); writeShellApplication's own
  # buildCommand can't be extended with a postInstall (it bypasses
  # genericBuild's phases entirely), hence merging the completions in here via
  # symlinkJoin instead of adding them to scoite-unwrapped directly.
  #
  # `sc` is the short alias — a real binary, not a shell abbr, so it works from
  # any shell, from scripts, and over `ssh abhaile sc list`. (A `sandvm` shim
  # lived here from the 2026-08-24 rename until 2026-08-25; it is gone.)
  postBuild = ''
    ln -s scoite $out/bin/sc

    mkdir -p $out/share/fish/vendor_completions.d
    cp ${./completions.fish} $out/share/fish/vendor_completions.d/scoite.fish
    cp ${./completions.fish} $out/share/fish/vendor_completions.d/sc.fish
    sed -i 's/-c scoite/-c sc/g' $out/share/fish/vendor_completions.d/sc.fish
  '';
  meta = scoite-unwrapped.meta;
}
