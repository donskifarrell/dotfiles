# `bbm-deploy` — build bbm from a local working copy and deploy it to eachtrach.
#
# Piggybacks on deploy-rs rather than replacing it: this only decides WHICH bbm
# source the build sees, then hands off to `deploy`, magic rollback and all.
#
# Why an override rather than `nix flake update bbm`: the input already points
# at a local checkout (services/bbm.nix), so an update would only rewrite
# flake.lock on every deploy — churn in the dotfiles repo that records nothing
# you would want to keep. Overriding per-invocation leaves the lock alone, and
# additionally lets --src deploy from a checkout somewhere else entirely.
# deploy-rs forwards trailing args to `nix build`
# (`deploy [OPTS] [TARGET] [-- ARGS]`), so the override reaches every build.
{
  writeShellApplication,
  git,
  nix,
  deploy-rs,
  coreutils,
}:
writeShellApplication {
  name = "bbm-deploy";
  meta.description = "Deploy bbm from a local working copy to eachtrach (deploy-rs)";
  runtimeInputs = [
    git
    nix
    deploy-rs
    coreutils
  ];
  text = ''
    host="eachtrach"
    src=""
    pinned=0
    dirty=0
    deploy_args=()

    die() {
      echo "bbm-deploy: $1" >&2
      exit 1
    }

    usage() {
      cat <<'USAGE'
    Usage: bbm-deploy [OPTIONS]

    Builds bbm from a local working copy on this machine and deploys the result
    to eachtrach over the tailnet. Run it from inside the dotfiles repo.

    Options:
      --src PATH      bbm working copy. Default: $BBM_SRC, else <dotfiles>/../dev/bbm.
      --pinned        Ignore any working copy; deploy the rev already in flake.lock.
      --dirty         Allow an uncommitted working copy (deploys the worktree as-is,
                      minus anything .gitignore'd). Default is to refuse.
      --host NAME     Deploy node to target (default: eachtrach).
      --dry           deploy-rs --dry-activate: build and show, do not switch.
      --skip-checks   deploy-rs -s: skip its pre-build checks.
      -h, --help      This text.

    Leaves flake.lock alone: the source is chosen per-invocation, not committed.
    USAGE
    }

    while [ $# -gt 0 ]; do
      case "$1" in
        --src) src="''${2:-}"; [ -n "$src" ] || die "--src needs a path"; shift 2 ;;
        --pinned) pinned=1; shift ;;
        --dirty) dirty=1; shift ;;
        --host) host="''${2:-}"; [ -n "$host" ] || die "--host needs a name"; shift 2 ;;
        --dry) deploy_args+=(--dry-activate); shift ;;
        --skip-checks) deploy_args+=(-s); shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1 (try --help)" ;;
      esac
    done

    repo="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    [ -n "$repo" ] || die "run this from inside the dotfiles repo"
    [ -f "$repo/flake.nix" ] || die "$repo has no flake.nix"

    build_args=()

    if [ "$pinned" -eq 1 ]; then
      echo "bbm-deploy: deploying the bbm rev pinned in flake.lock"
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
          die "no bbm working copy found. Pass --src PATH, set BBM_SRC, or use --pinned."
        fi
      fi

      src="$(cd "$src" && pwd)" || die "cannot resolve --src"
      [ -f "$src/flake.nix" ] || die "$src has no flake.nix (is it a bbm checkout?)"
      grep -q '^module bbm/v2$' "$src/go.mod" 2>/dev/null || die "$src is not a bbm checkout"

      if [ -n "$(git -C "$src" status --porcelain)" ]; then
        # A dirty tree deploys files that exist on this machine and nowhere
        # else, and the version string degrades to "-dirty" — recoverable, but
        # never what you want by accident.
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
