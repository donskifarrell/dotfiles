{
  writeShellApplication,
  nh,
  nix,
  coreutils,
}:
writeShellApplication {
  name = "nix-flake-build";
  meta.description = "Build or activate a host configuration with nh";

  runtimeInputs = [
    nh
    nix
    coreutils
  ];
  text = ''
    usage() {
      cat <<'USAGE'
    Usage: nix-flake-build [OPTIONS] [HOST...]

    Build (default) or activate host configurations with nh, picking
    `nh os` / `nh darwin` / `nh home` from where the name is defined
    (nixosConfigurations / darwinConfigurations / homeConfigurations).

    Options:
      --switch          build + activate (nh <platform> switch)
      --boot            build + make boot default (NixOS only)
      --test            build + activate without a boot entry (NixOS only)
      --on USER@HOST    deploy to a remote machine over SSH (NixOS only;
                        passed to nh os as --target-host)
      -h, --help        show this help
      -- ARGS           extra arguments passed through to nh

    HOST defaults to the local hostname. Multiple hosts are processed
    sequentially (build mode only).
    USAGE
    }

    op="build"
    remote=""
    hosts=()
    extra=()

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --switch) op="switch"; shift ;;
        --boot) op="boot"; shift ;;
        --test) op="test"; shift ;;
        --on) remote="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        --) shift; extra=("$@"); break ;;
        -*) echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
        *) hosts+=("$1"); shift ;;
      esac
    done

    if [[ "''${#hosts[@]}" -eq 0 ]]; then
      hosts=("$(uname -n)")
    fi

    if [[ "''${#hosts[@]}" -gt 1 && "$op" != "build" ]]; then
      echo "error: --$op only supports a single host" >&2
      exit 1
    fi

    # attrNames is lazy: none of this evaluates a full configuration.
    names() {
      nix eval --raw ".#$1" --apply \
        'cfgs: builtins.concatStringsSep " " (builtins.attrNames cfgs)' 2>/dev/null || true
    }
    nixos_hosts=" $(names nixosConfigurations) "
    darwin_hosts=" $(names darwinConfigurations) "
    home_cfgs=" $(names homeConfigurations) "

    rc=0
    for h in "''${hosts[@]}"; do
      if [[ "$nixos_hosts" == *" $h "* ]]; then
        cmd=(nh os "$op" . -H "$h")
        if [[ -n "$remote" ]]; then
          cmd+=(--target-host "$remote")
        fi
      elif [[ "$darwin_hosts" == *" $h "* ]]; then
        if [[ -n "$remote" || "$op" == "boot" || "$op" == "test" ]]; then
          echo "error: --on/--boot/--test are not supported for darwin host '$h'" >&2
          exit 1
        fi
        cmd=(nh darwin "$op" . -H "$h")
      elif [[ "$home_cfgs" == *" $h "* ]]; then
        if [[ -n "$remote" || "$op" == "boot" || "$op" == "test" ]]; then
          echo "error: --on/--boot/--test are not supported for home config '$h'" >&2
          exit 1
        fi
        cmd=(nh home "$op" . -c "$h")
      else
        echo "error: '$h' not found in nixosConfigurations, darwinConfigurations or homeConfigurations" >&2
        rc=1
        continue
      fi

      echo "+ ''${cmd[*]} ''${extra[*]}" >&2
      "''${cmd[@]}" "''${extra[@]}" || rc=$?
    done
    exit "$rc"
  '';
}
