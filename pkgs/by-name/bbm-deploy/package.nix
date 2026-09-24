# `bbm-deploy` — deploy bbm to eachtrach, from the pinned remote or a local checkout.
#
# Piggybacks on deploy-rs rather than replacing it: this only decides WHICH bbm
# source the build sees, then hands off to `deploy`, magic rollback and all.
#
# DEFAULT IS THE PIN. With no flags this deploys the bbm rev in flake.lock,
# which since 2026-09-24 is the GitHub remote (services/bbm.nix). That makes a
# bare `bbm-deploy` reproducible and reviewable: what ships is a pushed commit.
# `--local` opts back into building from a working copy on this machine.
#
# Before 2026-09-24 the local checkout was the default and the input itself
# pointed at ~/dev/bbm. That was reversed because a dirty local input silently
# stopped `nix flake update` writing flake.lock AT ALL, repo-wide.
#
# Why an override rather than `nix flake update bbm`: an update would rewrite
# flake.lock on every local deploy — churn in the dotfiles repo recording
# nothing you would want to keep. Overriding per-invocation leaves the lock
# alone, and additionally lets --local deploy from a checkout elsewhere.
# deploy-rs forwards trailing args to `nix build`
# (`deploy [OPTS] [TARGET] [-- ARGS]`), so the override reaches every build.
{
  writeShellApplication,
  git,
  nix,
  deploy-rs,
  coreutils,
  gnugrep,
}:
writeShellApplication {
  name = "bbm-deploy";
  meta.description = "Deploy bbm to eachtrach from the pinned remote or a local checkout (deploy-rs)";
  runtimeInputs = [
    git
    nix
    deploy-rs
    coreutils
    gnugrep
  ];
  text = ''
    host="eachtrach"
    src=""
    use_local=0
    pinned_explicit=0
    dirty=0
    deploy_args=()

    die() {
      echo "bbm-deploy: $1" >&2
      exit 1
    }

    usage() {
      cat <<'USAGE'
    Usage: bbm-deploy [OPTIONS]

    Deploys bbm to eachtrach over the tailnet. By default it deploys the bbm
    rev pinned in flake.lock (the GitHub remote) — a pushed, reproducible
    commit. Run it from inside the dotfiles repo.

    Source selection:
      --local [PATH]  Build from a local checkout instead of the pinned remote.
                      PATH is optional; without it: $BBM_SRC, else
                      <dotfiles>/../dev/bbm. Refuses a dirty tree (see --dirty).
      --src PATH      Same as --local PATH.
      --pinned        Explicitly the default: deploy the rev in flake.lock.
      --dirty         Implies --local. Allow an uncommitted working copy; the
                      worktree is exported as-is, minus anything .gitignore'd.

    Other options:
      --host NAME     Deploy node to target (default: eachtrach).
      --dry           deploy-rs --dry-activate: build and show, do not switch.
      --skip-checks   deploy-rs -s: skip its pre-build checks.
      -h, --help      This text.

    Leaves flake.lock alone: a local source is chosen per-invocation, never
    committed.
    USAGE
    }

    while [ $# -gt 0 ]; do
      case "$1" in
        # --local takes an OPTIONAL path: consume $2 only when it is not
        # another flag, so `--local` and `--local /path` both work.
        --local)
          use_local=1
          if [ $# -ge 2 ] && [ -n "''${2:-}" ] && [ "''${2#-}" = "$2" ]; then
            src="$2"; shift 2
          else
            shift
          fi
          ;;
        --src)
          src="''${2:-}"; [ -n "$src" ] || die "--src needs a path"
          use_local=1; shift 2
          ;;
        --pinned) pinned_explicit=1; shift ;;
        --dirty) dirty=1; use_local=1; shift ;;
        --host) host="''${2:-}"; [ -n "$host" ] || die "--host needs a name"; shift 2 ;;
        --dry) deploy_args+=(--dry-activate); shift ;;
        --skip-checks) deploy_args+=(-s); shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1 (try --help)" ;;
      esac
    done

    if [ "$use_local" -eq 1 ] && [ "$pinned_explicit" -eq 1 ]; then
      die "--pinned and --local/--src/--dirty are mutually exclusive"
    fi

    repo="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    [ -n "$repo" ] || die "run this from inside the dotfiles repo"
    [ -f "$repo/flake.nix" ] || die "$repo has no flake.nix"

    build_args=()

    if [ "$use_local" -eq 0 ]; then
      echo "bbm-deploy: deploying the bbm rev pinned in flake.lock (--local to use a working copy)"
    else
      # No hardcoded default: a path is discovered, or the caller states one.
      if [ -z "$src" ]; then
        if [ -n "''${BBM_SRC:-}" ]; then
          src="$BBM_SRC"
        elif [ -f "$repo/../dev/bbm/go.mod" ]; then
          src="$repo/../dev/bbm"
        elif [ -f "$PWD/go.mod" ] && grep -q '^module bbm/v2$' "$PWD/go.mod"; then
          src="$PWD"
        else
          die "no bbm working copy found. Pass --local PATH, set BBM_SRC, or drop --local to deploy the pin."
        fi
      fi

      src="$(cd "$src" && pwd)" || die "cannot resolve the bbm checkout path"
      [ -f "$src/flake.nix" ] || die "$src has no flake.nix (is it a bbm checkout?)"
      grep -q '^module bbm/v2$' "$src/go.mod" 2>/dev/null || die "$src is not a bbm checkout"

      # The prod overlay is NOT carried by the build. bbm layers .env then
      # .env.$ENV, and eachtrach runs ENV=prod against a .env.prod that
      # services/bbm.nix renders from sops — because $src/.env.prod is
      # .gitignore'd (so the export cannot see it) and holds a bot token that
      # must not leave sops for the world-readable store.
      #
      # The cost of that split is drift: a key added to $src/.env.prod reaches
      # local runs and nothing else. Warn rather than fail — a key can be
      # local-only on purpose, and this must never block a deploy.
      overlay="$src/.env.prod"
      aspect="$repo/modules/den/aspects/services/bbm.nix"
      if [ -f "$overlay" ] && [ -f "$aspect" ]; then
        missing=()
        while read -r key; do
          [ -n "$key" ] || continue
          # Case-insensitive: the aspect names secrets by their sops key
          # (bbm/telegram_bot_token), non-secrets by the variable itself. A
          # match in a comment counts as considered-and-decided.
          grep -qi -- "$key" "$aspect" || missing+=("$key")
        done < <(grep -oE '^[[:space:]]*(export[[:space:]]+)?[A-Z_][A-Z0-9_]*=' "$overlay" |
                   grep -oE '[A-Z_][A-Z0-9_]*' || true)
        if [ "''${#missing[@]}" -gt 0 ]; then
          echo "bbm-deploy: WARNING $overlay sets keys the deployed config never mentions:" >&2
          printf '  %s\n' "''${missing[@]}" >&2
          echo "  Add them to sops.templates.\".env.prod\" in $aspect (or to sops, if secret)." >&2
        fi
      fi

      if [ -n "$(git -C "$src" status --porcelain)" ]; then
        # A dirty tree deploys files that exist on this machine and nowhere
        # else, and the version string degrades to "-dirty" — recoverable, but
        # never what you want by accident. This check, not the flakeref form,
        # is what keeps uncommitted work out of a deploy: under lazy-trees nix
        # exports the live worktree for `git+file:` too (verified 2026-09-24).
        [ "$dirty" -eq 1 ] || die "$src has uncommitted changes. Commit them, or pass --dirty."
        echo "bbm-deploy: WARNING deploying an uncommitted worktree at $src"
        build_args+=(--override-input bbm "$src")
      else
        echo "bbm-deploy: deploying bbm $(git -C "$src" rev-parse --short HEAD) from $src"
        build_args+=(--override-input bbm "git+file://$src")
      fi
    fi

    if [ "''${#build_args[@]}" -gt 0 ]; then
      exec deploy "''${deploy_args[@]}" "$repo#$host" -- "''${build_args[@]}"
    fi
    exec deploy "''${deploy_args[@]}" "$repo#$host"
  '';
}
