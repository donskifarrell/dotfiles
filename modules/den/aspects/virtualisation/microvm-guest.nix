# Guest-side shape of a `sandvm` sandbox — see modules/den/hosts/sandvm.nix for
# the four hosts that carry this aspect (one per sandbox type) and
# docs/microvm-sandbox.md for the full picture (why virtiofs for /workspace,
# why the SSH host key is shared not generated per-boot, what's deliberately
# NOT shared).
#
# Everything read impurely below (`builtins.getEnv`, set by the `sandvm` CLI)
# is deliberately confined to options that only affect the *runner script* —
# qemu's command line — never `system.build.toplevel`. That's what lets every
# instance of a type share one already-built system closure: relaunching with
# a different workdir/port/cpu/mem rebuilds a ~2 kB shell script, not a NixOS
# generation. Anything genuinely per-instance that the *guest* needs to know
# (its name, its credentials) arrives at boot as a systemd credential over
# fw_cfg instead, which costs no eval at all.
{ inputs, lib, ... }:
let
  getEnvOr =
    name: default:
    let
      v = builtins.getEnv name;
    in
    if v == "" then default else v;

  # `nix flake check`/`nix build` evaluate `system.build.toplevel` purely
  # (no `--impure`), where `builtins.getEnv` always reads "" — so this can't
  # be a hard assertion (that would fail flake check for everyone, always).
  # Fall back to a real, harmless, always-present directory instead; `lib.warn`
  # surfaces the mistake without failing evaluation (this repo already runs
  # with `abort-on-warn = false`, so that's the established idiom here).
  workdirRaw = builtins.getEnv "MICROVM_WORKDIR";
  workdir =
    if workdirRaw == "" then
      lib.warn "MICROVM_WORKDIR unset — sharing /var/empty as /workspace. Launch via the `sandvm` command (pkgs/by-name/sandvm), not `nix run`/`nix build` directly." "/var/empty"
    else
      workdirRaw;

  sshPort = lib.toIntBase10 (getEnvOr "MICROVM_SSH_PORT" "2222");
  vcpu = lib.toIntBase10 (getEnvOr "MICROVM_CPU" "4");
  mem = lib.toIntBase10 (getEnvOr "MICROVM_MEM" "32768");

  # Volume sizes (MiB). Both images are sparse files that only cost host disk
  # as the guest actually writes into them, and both are grown in place by
  # `sandvm resize` (truncate + QMP block_resize + the boot-time grow-fs unit
  # below), so these are generous ceilings rather than reservations.
  diskMib = lib.toIntBase10 (getEnvOr "MICROVM_DISK" "32768");
  homeMib = lib.toIntBase10 (getEnvOr "MICROVM_HOME_DISK" "16384");

  extraPorts =
    let
      raw = builtins.getEnv "MICROVM_PORTS";
    in
    map lib.toIntBase10 (lib.filter (s: s != "") (lib.splitString "," raw));

  # Host-side bind address for every forwarded port. The CLI allocates one
  # 127.x.y.1 per instance (see `free_addr` in pkgs/by-name/sandvm), which is
  # what lets guest ports map 1:1 — a guest's :8080 lands on 127.x.y.1:8080
  # and so cannot collide with abhaile's own llama-server on 127.0.0.1:8080,
  # nor with any other sandbox. It also keeps forwards genuinely host-only:
  # microvm.nix defaults `host.address` to "", which qemu renders as "bind all
  # interfaces" — every sandbox's ports (ssh included) were being offered to
  # the LAN, contradicting the host-only design in docs/microvm-sandbox.md.
  hostAddr = getEnvOr "MICROVM_HOST_ADDR" "127.0.0.1";

  # MICROVM_PORTS already carries the full effective set — the CLI's default
  # dev-port list plus any `--port`, minus whatever the host currently holds on
  # a wildcard address (see `effective_ports` in pkgs/by-name/sandvm). That
  # filtering has to happen against live host state, so it cannot live here.
  # This end only guards the two shapes qemu refuses to start with: a duplicate
  # host port, or a second rule on the ssh port. Either one aborts the whole VM
  # with "Could not set up host forwarding", not just that rule.
  forwardedPorts = lib.filter (p: p != sshPort) (lib.unique extraPorts);

  # Host paths of per-launch credential files. Kept as *strings*, never Nix
  # path literals: microvm.credentialFiles embeds the path in the runner
  # script and qemu reads the contents at VM start via fw_cfg, so the material
  # never enters the world-readable /nix/store. (A path literal would defeat
  # the whole point by copying the file into the store at eval time.) The CLI
  # only sets each var when the corresponding host file exists.
  credentialEnv = {
    # ~/.config/sandvm/agent.env + the omp auth-broker token: KEY=value lines
    # exported into every guest shell.
    AGENT_ENV = builtins.getEnv "MICROVM_AGENT_ENV";
    # df's ~/.config/git/gitconfig.local (a sops secret on the host):
    # user.name/user.email, no key material.
    GITCONFIG_LOCAL = builtins.getEnv "MICROVM_GITCONFIG";
    # df's live claude-code OAuth credential, refreshed into the guest on
    # every launch so a sandbox never has to run `claude login` of its own.
    CLAUDE_CREDS = builtins.getEnv "MICROVM_CLAUDE_CREDS";
    # A file holding the instance name — the one genuinely per-instance
    # *guest-visible* fact. Delivered as a credential rather than baked into
    # networking.hostName so the system closure stays identical across
    # instances. (credentialFiles values are paths, never inline values.)
    INSTANCE = builtins.getEnv "MICROVM_INSTANCE_FILE";
  };
in
{
  den.aspects.virtualization.microvm-guest.nixos =
    { pkgs, ... }:
    {
      imports = [ inputs.microvm.nixosModules.microvm ];

      # Guest networking: systemd-networkd DHCP on the SLIRP interface.
      # roles.default no longer ships NetworkManager/avahi (2026-07-14) — a
      # desktop network daemon was the single biggest guest boot-time/RAM
      # cost, and mDNS behind SLIRP reaches nothing.
      networking.useNetworkd = true;
      systemd.network.wait-online.anyInterface = true;

      # No firewall in the guest, deliberately. SLIRP gives a sandbox exactly
      # one inbound path — a `hostfwd` rule held by qemu on the host — so the
      # forwardPorts list below *is* the access-control list; an in-guest
      # firewall only adds a second, invisible one that has to be kept in sync
      # with it. Nothing here used to set this, so guests ran NixOS's default:
      # enabled, port 22 only (from services.openssh.openFirewall), policy
      # DROP. That silently black-holed every `sandvm --port N` — the host-side
      # connect succeeded (qemu accepts on the host side before it dials the
      # guest), the request then hit a DROP with no RST, and curl hung forever
      # with no error anywhere. Ports nothing forwards stay unreachable for the
      # solid reason that qemu is not listening on them.
      networking.firewall.enable = false;

      # Static, deliberately: Den would derive this from the Den host name
      # ("sandvm-devenv", …) and the previous design forced it to the
      # per-launch instance name — which put the instance name inside
      # /etc and so gave every sandbox its own system closure. The real
      # hostname is set at boot from the INSTANCE credential by
      # sandvm-hostname.service below.
      networking.hostName = lib.mkForce "sandbox";

      microvm = {
        inherit vcpu mem;
        hypervisor = "qemu";

        # Big ceiling, small footprint: qemu allocates guest RAM lazily (only
        # pages the guest touches cost host memory), and microvm.nix's qemu
        # runner wires this balloon with free-page-reporting=on — freed guest
        # pages are returned to the host automatically, no QMP babysitting.
        balloon = true;

        # Usermode (SLIRP) networking: no host tap/bridge setup, host-only
        # reachability by design (see docs/microvm-sandbox.md).
        interfaces = [
          {
            type = "user";
            id = "usernet0";
            mac = "02:00:00:01:01:01";
          }
        ];

        forwardPorts = [
          {
            from = "host";
            host = {
              address = hostAddr;
              port = sshPort;
            };
            guest.port = 22;
          }
        ]
        ++ map (p: {
          from = "host";
          host = {
            address = hostAddr;
            port = p;
          };
          guest.port = p;
        }) forwardedPorts;

        # ro-store/hostkey stay 9p (built into qemu, no companion process,
        # and read-mostly so 9p's ownership quirks don't matter). workspace
        # is virtiofs: qemu's 9p security models squash pre-existing files'
        # ownership to root as seen by the guest since qemu runs unprivileged
        # here, so df could not write into an already-populated project dir.
        # virtiofsd passes through real host uid/gid, which works because the
        # guest's iosta is uid 1000, matching the host.
        shares = [
          {
            tag = "ro-store";
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
          }
          {
            tag = "workspace";
            proto = "virtiofs";
            source = workdir;
            mountPoint = "/workspace";
          }
          {
            tag = "hostkey";
            source = "/var/lib/sandvm/hostkey";
            mountPoint = "/etc/sandvm-hostkey";
          }
        ];

        # Host's /nix/store is shared read-only (above) — without a writable
        # overlay the guest's whole store is read-only and nix-daemon
        # auto-disables, which breaks home-manager activation *and* the point
        # of the generic/devenv tiers: installing a project's (or an agent's)
        # own dependencies at runtime. overlayfs can't use 9p/virtiofs as an
        # upper layer, so it has to be a disk image.
        writableStoreOverlay = "/nix/.rw-store";
        volumes = [
          {
            image = "nix-store-overlay.img";
            mountPoint = "/nix/.rw-store";
            size = diskMib;
          }
          # Persistent /home. This is what makes "a box the agent installs its
          # own tools into" actually stick: `nix profile install`, npm/pip
          # --user, shell history, claude-code's own state and ~/.vscode-server
          # all survive stop→start, and `sandvm rm` is what throws them away.
          # (Until 2026-08-22 the home was tmpfs and only ~/.vscode-server had
          # a volume of its own.)
          {
            image = "home.img";
            mountPoint = "/home/iosta";
            size = homeMib;
          }
        ];

        credentialFiles = lib.filterAttrs (_: v: v != "") credentialEnv;
      };

      # roles.default's core.nix sets this repo-wide for disk savings; it's
      # asserted incompatible with microvm.writableStoreOverlay above.
      nix.settings.auto-optimise-store = lib.mkForce false;

      # Build/fetch from the *host's* store before reaching for the internet.
      # abhaile serves its own store over harmonia on loopback
      # (virtualisation.microvm-host), which SLIRP exposes to the guest at
      # 10.0.2.2 — so anything the host has already built or downloaded is a
      # LAN-speed copy instead of a rebuild or a cache.nixos.org fetch. The
      # guest already mounts that same store read-only, so this grants it
      # nothing it couldn't already read; unsigned is therefore fine, and
      # avoids having to manage a signing key on the host just to talk to
      # ourselves.
      nix.settings = {
        substituters = lib.mkBefore [ "http://10.0.2.2:5000" ];
        require-sigs = false;
        # Never let a stopped host cache stall a guest build.
        connect-timeout = lib.mkForce 3;
        fallback = true;
      };

      # `core.network.openssh` (via roles.default) already enables sshd with
      # publickey-only auth, no root password login, agent forwarding on.
      # Only `hostKeys` is guest-specific.
      services.openssh.hostKeys = [
        {
          path = "/etc/sandvm-hostkey/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];

      # VSCode Remote-SSH (`code --remote ssh-remote+sandvm-<name> /workspace`):
      # the extension downloads a prebuilt server whose node binary is
      # dynamically linked against /lib64/ld-linux-x86-64.so.2 — absent on
      # NixOS, so it dies on launch without this. nix-ld provides that loader;
      # no NIX_LD plumbing needed, it falls back to
      # /run/current-system/sw/share/nix-ld/lib/ld.so when the var is unset.
      programs.nix-ld.enable = true;

      # Console fallback: SSH pubkey is the intended way in, but a broken SSH
      # connection would otherwise leave the console login prompt with no
      # usable credentials. Not a security regression — the console is qemu's
      # own stdout, only reachable by whoever can already read the
      # `sandvm`-launching systemd-run unit.
      users.users.iosta.initialPassword = "iosta";

      # --- per-instance boot wiring ----------------------------------------

      # The instance's real name, from the fw_cfg credential (see the comment
      # on networking.hostName above).
      systemd.services.sandvm-hostname = {
        description = "Set the hostname from the launch-time INSTANCE credential";
        wantedBy = [ "multi-user.target" ];
        before = [ "sshd.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ImportCredential = "INSTANCE";
        };
        script = ''
          if [ -s "$CREDENTIALS_DIRECTORY/INSTANCE" ]; then
            ${pkgs.nettools}/bin/hostname "$(cat "$CREDENTIALS_DIRECTORY/INSTANCE")"
          fi
        '';
      };

      # Fresh ext4 mounts root-owned, and iosta must own its own home before
      # home-manager activation or the Remote-SSH bootstrap runs. NOT a
      # tmpfiles `z` rule: tmpfiles refuses to touch a root-owned path under a
      # user-owned home ("Detected unsafe path transition"), which is exactly
      # the state this exists to fix. Default unit deps already order it after
      # local-fs.target, i.e. after the mount.
      systemd.services.sandvm-home-perms = {
        description = "Hand the persistent /home/iosta volume to iosta";
        wantedBy = [ "multi-user.target" ];
        before = [
          "home-manager-iosta.service"
          "sshd.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          chown iosta:users /home/iosta
          chmod 0700 /home/iosta
        '';
      };

      # "Expand in size as needed": `sandvm resize` grows the backing image on
      # the host and, for a running guest, the virtio-blk device via QMP. This
      # stretches the filesystem onto whatever space the device now has.
      # Online resize2fs on a mounted ext4 is a fast no-op when the fs already
      # fills its device, which is what lets this run both at boot (picking up
      # a resize done while stopped) and on a timer (picking up a live one)
      # without any host->guest signalling channel.
      systemd.services.sandvm-grow-fs = {
        description = "Grow the sandbox filesystems to fill their (possibly resized) volumes";
        wantedBy = [ "multi-user.target" ];
        before = [
          "home-manager-iosta.service"
          "nix-daemon.service"
        ];
        after = [ "local-fs.target" ];
        path = [
          pkgs.e2fsprogs
          pkgs.util-linux
        ];
        # Not RemainAfterExit: the timer below has to be able to run it again.
        serviceConfig.Type = "oneshot";
        script = ''
          for mp in /nix/.rw-store /home/iosta; do
            dev=$(findmnt -no SOURCE "$mp" || true)
            [ -b "$dev" ] || continue
            # Quiet: the overwhelmingly common outcome is "nothing to do".
            resize2fs "$dev" >/dev/null 2>&1 || true
          done
        '';
      };

      systemd.timers.sandvm-grow-fs = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "2min";
          OnUnitActiveSec = "2min";
        };
      };

      # Cloud LLM keys: install the AGENT_ENV credential where iosta's shells
      # can read it. /run is tmpfs, so it evaporates on stop.
      systemd.services.sandvm-agent-env = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ImportCredential = "AGENT_ENV";
        };
        script = ''
          if [ -f "$CREDENTIALS_DIRECTORY/AGENT_ENV" ]; then
            install -m 0600 -o iosta -g users \
              "$CREDENTIALS_DIRECTORY/AGENT_ENV" /run/agent.env
          fi
        '';
      };

      # Git identity: install the GITCONFIG_LOCAL credential exactly where
      # dev.git's `include.path = ~/.config/git/gitconfig.local` already looks.
      # Without it, commits in the guest fail with "Author identity unknown".
      # Name/email only — the includeIf org targets it references stay absent
      # and git silently skips missing includes.
      systemd.services.sandvm-gitconfig = {
        wantedBy = [ "multi-user.target" ];
        after = [ "sandvm-home-perms.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ImportCredential = "GITCONFIG_LOCAL";
        };
        script = ''
          if [ -f "$CREDENTIALS_DIRECTORY/GITCONFIG_LOCAL" ]; then
            install -d -m 0755 -o iosta -g users /home/iosta/.config
            install -d -m 0700 -o iosta -g users /home/iosta/.config/git
            install -m 0600 -o iosta -g users \
              "$CREDENTIALS_DIRECTORY/GITCONFIG_LOCAL" \
              /home/iosta/.config/git/gitconfig.local
          fi
        '';
      };

      # claude-code's own OAuth credential, copied from the host on every
      # launch (df's decision, 2026-08-22: zero-touch beats one `claude login`
      # per instance). It is refreshed each launch rather than left to age in
      # the persistent home, so a sandbox that has been stopped for a week
      # still starts with a live token. This *is* a real credential inside the
      # sandbox — see docs/microvm-sandbox.md, "What's deliberately NOT
      # shared", for why that trade was accepted and what it exposes.
      systemd.services.sandvm-claude-creds = {
        wantedBy = [ "multi-user.target" ];
        after = [ "sandvm-home-perms.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ImportCredential = "CLAUDE_CREDS";
        };
        script = ''
          if [ -f "$CREDENTIALS_DIRECTORY/CLAUDE_CREDS" ]; then
            install -d -m 0700 -o iosta -g users /home/iosta/.claude
            install -m 0600 -o iosta -g users \
              "$CREDENTIALS_DIRECTORY/CLAUDE_CREDS" \
              /home/iosta/.claude/.credentials.json
          fi
        '';
      };

      # Dependency pre-install (devenv/workstation tiers care most, but it is
      # harmless everywhere): if the mounted project declares its toolchain,
      # build it once at boot so the environment is already in the guest's
      # persistent store overlay before anyone attaches. Failures are logged,
      # never fatal — a broken flake must not stop the sandbox from booting.
      systemd.services.sandvm-workspace-init = {
        description = "Pre-install /workspace project dependencies (devenv/flake)";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [
          "network-online.target"
          "sandvm-grow-fs.service"
        ];
        unitConfig.ConditionPathIsDirectory = "/workspace";
        path = [
          pkgs.devenv
          pkgs.git
          pkgs.nix
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "iosta";
          Group = "users";
          WorkingDirectory = "/workspace";
        };
        script = ''
          if [ -f devenv.nix ] && command -v devenv >/dev/null; then
            echo "devenv.nix found - building the devenv environment"
            devenv shell true || echo "devenv setup failed (non-fatal)"
          elif [ -f flake.nix ]; then
            echo "flake.nix found - building the flake devShell"
            nix develop --command true || echo "devShell setup failed (non-fatal)"
          fi
        '';
      };

      # Land every session in /workspace, not in $HOME — that is the only
      # thing a sandbox exists to work on. loginShellInit runs before
      # interactiveShellInit, so herdr's autostart (dev.tools.herdr.autostart)
      # inherits the directory too.
      programs.fish.loginShellInit = ''
        if test -d /workspace; and test "$PWD" = "$HOME"
          cd /workspace
        end
      '';

      # Export /run/agent.env's KEY=value lines into every fish session
      # (covers ssh logins, VSCode terminals, herdr panes, and non-interactive
      # `ssh guest cmd`). Native fish syntax on the fish-specific option — sh
      # in environment.shellInit would get babelfish-translated at build time,
      # which can't translate sourcing a runtime sh file.
      programs.fish.shellInit = ''
        if test -r /run/agent.env
          for line in (grep -E '^[A-Za-z_][A-Za-z0-9_]*=' /run/agent.env)
            set -l kv (string split -m 1 = -- $line)
            set -gx $kv[1] $kv[2]
          end
        end

        # Forwarded ssh-agent (dev.tools.sandvm sets ForwardAgent for sandvm-*
        # hosts): pin SSH_AUTH_SOCK to a stable path. sshd mints a fresh
        # random socket per connection, so long-lived herdr panes would
        # otherwise hold a dead path after an ssh drop/reattach.
        if set -q SSH_AUTH_SOCK; and test "$SSH_AUTH_SOCK" != "$HOME/.ssh/agent.sock"; and test -S "$SSH_AUTH_SOCK"
          mkdir -p "$HOME/.ssh"
          ln -sf "$SSH_AUTH_SOCK" "$HOME/.ssh/agent.sock"
        end
        if test -S "$HOME/.ssh/agent.sock"
          set -gx SSH_AUTH_SOCK "$HOME/.ssh/agent.sock"
        end
      '';

      # git push/pull over the forwarded agent shouldn't stall on an
      # interactive host-key prompt. GitHub's published ed25519 key.
      programs.ssh.knownHosts."github.com".publicKey =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

      # Local LLM: abhaile's llama-server (services.llm, 127.0.0.1:8080) is
      # reachable from the guest at qemu's SLIRP gateway. Pre-declare it as an
      # omp provider; model ids/context sizes must match the router presets in
      # modules/den/aspects/services/llm.nix. Seeded with tmpfiles `C` (copy,
      # only if absent) so omp can rewrite it at runtime.
      systemd.tmpfiles.rules =
        let
          # Only qwen: omp's own harness overhead measured ~17.1k tokens, so
          # llama-3.1-8b's 16k server-side ctx-size 400s on every request.
          ompModels = pkgs.writeText "omp-models.yml" ''
            providers:
              local:
                baseUrl: http://10.0.2.2:8080/v1
                auth: none
                api: openai-completions
                models:
                  - id: qwen3.6-35b-a3b
                    name: Qwen3.6 35B A3B (abhaile llama-server)
                    contextWindow: 65536
                    maxTokens: 8192
          '';
        in
        [
          "d /home/iosta/.omp 0755 iosta users - -"
          "d /home/iosta/.omp/agent 0755 iosta users - -"
          "C /home/iosta/.omp/agent/models.yml 0644 iosta users - ${ompModels}"
        ];
    };
}
