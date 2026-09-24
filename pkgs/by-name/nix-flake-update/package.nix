{
  writeShellApplication,
  gh,
  git,
  jq,
  nix,
  coreutils,
}:
writeShellApplication {
  name = "nix-flake-update";
  meta.description = "Update flake inputs with GitHub access token";
  runtimeInputs = [
    gh
    git
    jq
    nix
    coreutils
  ];
  text = ''
        excludes=()
        dry_run=1
        dry_run_host="$(uname -n)"

        # Parse arguments
        while [[ $# -gt 0 ]]; do
          case $1 in
            --exclude|-e)
              excludes+=("$2")
              shift 2
              ;;
            --no-dry-run)
              dry_run=0
              shift
              ;;
            --dry-run-host)
              dry_run_host="$2"
              shift 2
              ;;
            --help|-h)
              echo "Usage: nix-flake-update [OPTIONS]"
              echo ""
              echo "Options:"
              echo "  -e, --exclude INPUT   Exclude INPUT from update (can be specified multiple times)"
              echo "  --dry-run-host HOST   Host config to dry-run after updating (default: local hostname)"
              echo "  --no-dry-run          Skip the post-update build dry-run summary"
              echo "  -h, --help            Show this help message"
              echo ""
              echo "Refuses to run if a local (file:// or path:) input has an uncommitted"
              echo "worktree: nix would silently decline to write flake.lock at all."
              exit 0
              ;;
            *)
              echo "Unknown option: $1"
              exit 1
              ;;
          esac
        done

        # THE SILENT NO-OP. An input pointing at a local git tree with uncommitted
        # changes is an "unlocked" input, and nix then refuses to write flake.lock
        # AT ALL -- not just for that input. Every other input keeps its old rev,
        # the whole thing prints one warning, and exits 0. The rebuild that follows
        # produces a byte-identical store path, which reads as "the update had
        # nothing to do" rather than "the update did nothing".
        #
        # Found 2026-09-24 after 11 days of no-op updates, caused by a dirty
        # ~/dev/bbm back when the bbm input was a local checkout (services/bbm.nix
        # now points at the remote, so this should stay dormant -- that is the
        # point of keeping it).
        #
        # Both halves below are load-bearing. The preflight names the tree to clean
        # before any fetching happens; the post-check catches every other reason
        # nix may decline the write, including reasons that do not exist yet.

        # Root inputs resolved from a local path: `git+file://...` and `path:...`.
        # Nodes reached via `follows` are strings in .inputs; arrays are follows
        # targets and are somebody else's lock to worry about.
        list_dirty_local_inputs() {
          local meta
          meta="$(nix flake metadata --json 2>/dev/null)" || return 0

          local name path
          while IFS="$(printf '\t')" read -r name path; do
            [[ -n "$path" ]] || continue
            # Not a git checkout (a plain path: input) -- nothing to be dirty.
            git -C "$path" rev-parse --git-dir &>/dev/null || continue
            if [[ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]]; then
              printf '%s\t%s\n' "$name" "$path"
            fi
          done < <(jq -r '
            (.locks.nodes.root.inputs | to_entries
             | map(select(.value | type == "string") | .value)) as $names
            | .locks.nodes
            | to_entries[]
            | select(.key as $k | $names | index($k))
            | {name: .key, o: (.value.original // {})}
            | select(.o.type == "git" and (.o.url // "" | startswith("file://")))
              , select(.o.type == "path")
            | "\(.name)\t\((.o.url // .o.path) | sub("^file://";"") | sub("\\?.*$";""))"
          ' <<<"$meta" 2>/dev/null || true)
        }

        dirty_inputs="$(list_dirty_local_inputs)"
        if [[ -n "$dirty_inputs" ]]; then
          echo "nix-flake-update: REFUSING TO RUN -- local input(s) have an uncommitted worktree:" >&2
          while IFS="$(printf '\t')" read -r name path; do
            echo "  $name -> $path" >&2
          done <<<"$dirty_inputs"
          cat >&2 <<'MSG'

    Nix cannot lock a dirty tree, and it declines to write flake.lock at all when
    any input is unlocked -- so this update would fetch everything, write nothing,
    and exit 0. The following rebuild would then be a no-op you could mistake for
    "already up to date".

    Fix by doing one of:
      - commit (or stash) in the checkout(s) above, then re-run
      - point the input at its remote and override the source per-invocation
        instead (see pkgs/by-name/bbm-deploy for the pattern)
    MSG
          exit 1
        fi

        # After updating, dry-run the given host's toplevel so we can see what the
        # new lock turns into cache hits (fetched) vs cache misses (built). A long
        # "will be built" list is the signal that this update outran the binary
        # cache and a rebuild will compile.
        dry_run_summary() {
          local host="$1" attr

          # attrNames is lazy: this does not evaluate a full configuration.
          names() {
            nix eval --raw ".#$1" --apply \
              'cfgs: builtins.concatStringsSep " " (builtins.attrNames cfgs)' 2>/dev/null || true
          }
          local nixos_hosts darwin_hosts
          nixos_hosts=" $(names nixosConfigurations) "
          darwin_hosts=" $(names darwinConfigurations) "

          if [[ "$nixos_hosts" == *" $host "* ]]; then
            attr=".#nixosConfigurations.$host.config.system.build.toplevel"
          elif [[ "$darwin_hosts" == *" $host "* ]]; then
            attr=".#darwinConfigurations.$host.system"
          else
            echo "dry-run: '$host' not in nixos/darwin configurations; skipping" >&2
            return 0
          fi

          echo ""
          echo "== build dry-run for $host (built = cache miss / will compile) =="
          # --dry-run prints the built/fetched plan to stderr; surface it verbatim.
          nix build --dry-run "$attr" 2>&1 || true
        }

        # Run nix, show its output live, and fail if it declined to write the lock.
        # The warning is the only signal nix gives -- its exit status is 0 either way.
        run_update() {
          local log rc=0
          log="$(mktemp)"
          # shellcheck disable=SC2064
          trap "rm -f '$log'" RETURN

          if ! nix flake update "$@" 2>&1 | tee "$log"; then
            rc=1
          fi

          if grep -q 'not writing lock file' "$log"; then
            echo "" >&2
            echo "nix-flake-update: nix declined to write flake.lock -- NOTHING WAS UPDATED." >&2
            echo "The warning above names the input that blocked it." >&2
            return 1
          fi
          return "$rc"
        }

        # Check GitHub CLI auth status
        if ! gh auth status &>/dev/null; then
          echo "GitHub CLI not authenticated. Logging in..."
          gh auth login
        fi

        ACCESS_TOKEN="github.com=$(gh auth token)"

        if [[ ''${#excludes[@]} -eq 0 ]]; then
          # No excludes, update everything
          run_update --option access-tokens "$ACCESS_TOKEN"
        else
          # Build jq filter to exclude specified inputs
          jq_filter=".locks.nodes.root.inputs | keys[]"
          for exclude in "''${excludes[@]}"; do
            jq_filter="$jq_filter | select(. != \"$exclude\")"
          done

          # Get inputs to update
          inputs=$(nix flake metadata --json | jq -r "$jq_filter")

          if [[ -z "$inputs" ]]; then
            echo "No inputs to update after exclusions"
            exit 0
          fi

          # Build update-input arguments
          update_args=()
          while IFS= read -r input; do
            update_args+=("$input")
          done <<< "$inputs"

          echo "Updating inputs: $(echo "$inputs" | tr '\n' ' ')"
          echo "Excluding: ''${excludes[*]}"

          run_update --option access-tokens "$ACCESS_TOKEN" "''${update_args[@]}"
        fi

        if [[ "$dry_run" -eq 1 ]]; then
          dry_run_summary "$dry_run_host"
        fi
  '';
}
