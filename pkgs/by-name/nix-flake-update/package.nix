{
  writeShellApplication,
  gh,
  jq,
  nix,
  coreutils,
}:
writeShellApplication {
  name = "nix-flake-update";
  meta.description = "Update flake inputs with GitHub access token";
  runtimeInputs = [
    gh
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
          exit 0
          ;;
        *)
          echo "Unknown option: $1"
          exit 1
          ;;
      esac
    done

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

    # Check GitHub CLI auth status
    if ! gh auth status &>/dev/null; then
      echo "GitHub CLI not authenticated. Logging in..."
      gh auth login
    fi

    ACCESS_TOKEN="github.com=$(gh auth token)"

    if [[ ''${#excludes[@]} -eq 0 ]]; then
      # No excludes, update everything
      nix flake update --option access-tokens "$ACCESS_TOKEN"
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

      nix flake update --option access-tokens "$ACCESS_TOKEN" "''${update_args[@]}"
    fi

    if [[ "$dry_run" -eq 1 ]]; then
      dry_run_summary "$dry_run_host"
    fi
  '';
}
