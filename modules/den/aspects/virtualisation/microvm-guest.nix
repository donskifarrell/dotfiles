# Guest-side shape of a `sandvm` sandbox — see modules/den/hosts/sandvm.nix
# for the host that carries this aspect, and docs/microvm-sandbox.md for the
# full picture (why 9p not virtiofs, why the SSH host key is shared not
# generated per-boot, what's deliberately NOT shared into the guest).
#
# Only the three scalars below are runtime-parameterized (via env vars the
# `sandvm` wrapper script sets before `nix run --impure`), read with
# `builtins.getEnv` — that's the one bit of impurity this whole feature
# needs; everything else here is ordinary static Nix.
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
  vmName = getEnvOr "MICROVM_NAME" "sandvm";
  sshPort = lib.toIntBase10 (getEnvOr "MICROVM_SSH_PORT" "2222");
  vcpu = lib.toIntBase10 (getEnvOr "MICROVM_CPU" "4");
  mem = lib.toIntBase10 (getEnvOr "MICROVM_MEM" "32768");
  extraPorts =
    let
      raw = builtins.getEnv "MICROVM_PORTS";
    in
    map lib.toIntBase10 (lib.filter (s: s != "") (lib.splitString "," raw));

  # Host path of an optional KEY=value env file with cloud LLM API keys
  # (~/.config/sandvm/agent.env — the wrapper only sets this when the file
  # exists). Kept as a *string*: microvm.credentialFiles embeds the path in
  # the runner script and qemu reads the contents at VM start via fw_cfg, so
  # the key material never enters the world-readable /nix/store. (A Nix
  # *path literal* here would defeat the whole point by copying the file to
  # the store at eval time.)
  agentEnvFile = builtins.getEnv "MICROVM_AGENT_ENV";

  # Host path of df's ~/.config/git/gitconfig.local (sops secret:
  # user.name/user.email + the includeIf org identities) — same
  # string-not-path-literal reasoning as agentEnvFile above. The wrapper only
  # sets this when the file exists and is readable.
  gitconfigFile = builtins.getEnv "MICROVM_GITCONFIG";

in
{
  den.aspects.virtualization.microvm-guest.nixos =
    { pkgs, ... }:
    {
      imports = [ inputs.microvm.nixosModules.microvm ];

      # (The agent harness — omp — and claude-code come to iosta via
      # apps.ai-tools in roles.dev-sandbox, the same aspect that installs
      # them for df on real hosts. A duplicate guest-only systemPackages omp
      # lived here until 2026-07-14.)

      # Guest networking: systemd-networkd DHCP on the SLIRP interface.
      # roles.default no longer ships NetworkManager/avahi (2026-07-14) — a
      # desktop network daemon was the single biggest guest boot-time/RAM
      # cost, and mDNS behind SLIRP reaches nothing. useNetworkd +
      # useDHCP(default true) generates networkd's ethernet-default-dhcp
      # network for eth0; anyInterface lets network-online.target (the
      # workspace-init gate) fire as soon as that one link is up.
      networking.useNetworkd = true;
      systemd.network.wait-online.anyInterface = true;

      # Den sets networking.hostName from the static Den host name ("sandvm")
      # — mkForce so the per-launch instance name (e.g. the project's own
      # name) wins instead.
      networking.hostName = lib.mkForce vmName;

      microvm = {
        inherit vcpu mem;
        hypervisor = "qemu";

        # Big ceiling, small footprint: qemu allocates guest RAM lazily (only
        # pages the guest touches cost host memory), and microvm.nix's qemu
        # runner wires this balloon with free-page-reporting=on — freed guest
        # pages are returned to the host automatically, no QMP babysitting.
        # So the 32G default `mem` is a cap, not a reservation. deflate-on-oom
        # is on by default. (Fixed per-guest cost remains: the guest kernel's
        # struct page array, ~1.5% of `mem`, ~500M at 32G.)
        balloon = true;

        # Usermode (SLIRP) networking: no host tap/bridge setup, host-only
        # reachability by design (matches "connections from the local
        # machine", not the LAN — see docs/microvm-sandbox.md).
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
            host.port = sshPort;
            guest.port = 22;
          }
        ]
        ++ map (p: {
          from = "host";
          host.port = p;
          guest.port = p;
        }) extraPorts;

        # ro-store/hostkey stay 9p (built into qemu, no companion process,
        # and read-mostly so 9p's ownership quirks don't matter). workspace
        # is virtiofs: qemu's 9p "none"/"mapped" security models squash
        # pre-existing files' ownership to root as seen by the guest (they
        # only work for files the guest itself creates through the share, not
        # ones already on disk) since qemu runs unprivileged here — tried
        # both, neither let df write into an already-populated project dir.
        # virtiofsd passes through real host uid/gid directly, which just
        # works since the guest's df is uid 1000, matching the host. Costs a
        # companion `bin/virtiofsd-run` process (see the `sandvm` wrapper) —
        # see docs/microvm-sandbox.md for the full story.
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

        # Host's /nix/store is shared read-only (above) — without this, the
        # guest's entire /nix/store is read-only and nix-daemon auto-disables
        # (it "works only with a writable /nix/store", per microvm.nix), which
        # breaks home-manager activation *and* the actual point of having
        # devenv.sh in the guest: installing a project's own dependencies at
        # runtime. This overlay is what makes that possible. It's an
        # auto-created disk image, not a share, per microvm.nix's own
        # constraint (overlayfs can't use 9p/virtiofs as an upper layer) — the
        # `sandvm` wrapper runs qemu with its CWD set to the per-instance
        # state dir, so the relative path below lands there, not in the
        # project folder.
        writableStoreOverlay = "/nix/.rw-store";
        volumes = [
          {
            image = "nix-store-overlay.img";
            mountPoint = "/nix/.rw-store";
            size = 8192;
          }
          # ~/.vscode-server (the Remote-SSH server + its remote extensions)
          # would otherwise land in the ephemeral tmpfs home and be
          # re-downloaded on every boot — persist it per-instance, same
          # lifecycle/trust tier as the store overlay above (only ever holds
          # VS Code's own downloads; image is sparse, so 2G is a cap not a
          # cost). Fresh ext4 mounts root-owned — the
          # `vscode-server-volume-perms` oneshot below hands it to iosta.
          {
            image = "vscode-server.img";
            mountPoint = "/home/iosta/.vscode-server";
            size = 2048;
          }
        ];

        # Cloud LLM API keys (optional): qemu reads the host file at VM start
        # and hands it to the guest's systemd as a system credential over
        # fw_cfg — contents never touch the /nix/store on either side. See
        # `sandvm-agent-env.service` below for the guest-side consumption.
        credentialFiles =
          lib.optionalAttrs (agentEnvFile != "") {
            AGENT_ENV = agentEnvFile;
          }
          // lib.optionalAttrs (gitconfigFile != "") {
            GITCONFIG_LOCAL = gitconfigFile;
          };
      };

      # roles.default's core.nix sets this repo-wide for disk savings; it's
      # asserted incompatible with microvm.writableStoreOverlay above.
      nix.settings.auto-optimise-store = lib.mkForce false;

      # `core.network.openssh` (via roles.default) already enables sshd with
      # publickey-only auth, no root password login, agent forwarding on —
      # exactly what's wanted here. Only `hostKeys` is guest-specific.
      services.openssh.hostKeys = [
        {
          path = "/etc/sandvm-hostkey/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];

      # VSCode Remote-SSH (`code --remote ssh-remote+sandvm-<name> /workspace`,
      # the hint the wrapper prints): the extension downloads a prebuilt server
      # into ~/.vscode-server whose node binary is dynamically linked against
      # /lib64/ld-linux-x86-64.so.2 — absent on NixOS, so it dies on launch
      # without this. nix-ld provides that loader path; no NIX_LD env plumbing
      # is needed for it to reach sshd exec sessions — nix-ld falls back to
      # /run/current-system/sw/share/nix-ld/lib/ld.so when the var is unset.
      programs.nix-ld.enable = true;

      # The vscode-server volume's mount root: freshly-created ext4 is
      # root-owned, and iosta must be able to write into it or the Remote-SSH
      # bootstrap fails silently (VS Code just reports "Connecting with SSH
      # timed out"). NOT a tmpfiles `z` rule: tmpfiles refuses to touch a
      # root-owned path under a user-owned home ("Detected unsafe path
      # transition /home/iosta → /home/iosta/.vscode-server", observed in a
      # live guest) — the refusal triggers on exactly the state this needs to
      # fix. Default unit deps already order this after local-fs.target, i.e.
      # after the mount.
      systemd.services.vscode-server-volume-perms = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          chown iosta:users /home/iosta/.vscode-server
        '';
      };

      # (iosta's authorized key — df's public key — comes with the iosta user
      # aspect itself, modules/den/users/iosta.nix.)

      # Console fallback: iosta/root have no password set (deliberately — SSH
      # pubkey is the intended path in), which meant a broken SSH connection
      # left the console login prompt with no usable credentials at all. A
      # typeable throwaway password instead of autologin (which was tried and
      # rejected — an auto-dropped-into shell on every launch was unwanted) —
      # same "throwaway creds" pattern as virtualisation/vm-login.nix's debug
      # VM. Not a security regression: the console is qemu's own stdout, only
      # ever reachable by whoever can already read the `sandvm`-launching
      # systemd-run unit (df on the host) — the same principal SSH already
      # trusts. (herdr auto-start deliberately skips the console: it only
      # fires on SSH_TTY, so this fallback stays a plain fish shell.)
      users.users.iosta.initialPassword = "iosta";

      # Dependency pre-install: if the mounted project declares its toolchain
      # (devenv.nix or flake.nix), build it once at boot so the environment is
      # already in the guest's (persistent) store overlay before anyone
      # ssh'es in — and a relaunch after `sandvm stop` is a warm cache. Runs
      # as iosta (same uid as the host-side project owner; devenv writes its
      # .devenv/ state into /workspace). Failures are logged, never fatal — a
      # broken flake must not stop the sandbox from booting.
      systemd.services.sandvm-workspace-init = {
        description = "Pre-install /workspace project dependencies (devenv/flake)";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
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
          if [ -f devenv.nix ]; then
            echo "devenv.nix found - building the devenv environment"
            devenv shell true || echo "devenv setup failed (non-fatal)"
          elif [ -f flake.nix ]; then
            echo "flake.nix found - building the flake devShell"
            nix develop --command true || echo "devShell setup failed (non-fatal)"
          fi
        '';
      };

      # --- LLM access for the agent harness (omp) ---

      # Cloud keys: install the AGENT_ENV system credential (if the launch
      # passed one — see microvm.credentialFiles above) where iosta's shells
      # can read it. /run is tmpfs, so like everything else in the guest it
      # evaporates on stop.
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

      # Git identity: install the GITCONFIG_LOCAL credential (df's
      # gitconfig.local — user.name/user.email + includeIf lines) exactly
      # where dev.git's `include.path = ~/.config/git/gitconfig.local`
      # already looks. Without it, commits in the guest fail with "Author
      # identity unknown" — iosta's ephemeral home has no identity of its
      # own. The includeIf targets it references (gitconfig.pgstar, …) stay
      # absent in the guest and git silently skips missing includes, so only
      # the default identity applies. The parent dirs come from the tmpfiles
      # rules below (same pattern as .omp), which run before multi-user
      # services.
      systemd.services.sandvm-gitconfig = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ImportCredential = "GITCONFIG_LOCAL";
        };
        script = ''
          if [ -f "$CREDENTIALS_DIRECTORY/GITCONFIG_LOCAL" ]; then
            install -m 0600 -o iosta -g users \
              "$CREDENTIALS_DIRECTORY/GITCONFIG_LOCAL" \
              /home/iosta/.config/git/gitconfig.local
          fi
        '';
      };

      # Export /run/agent.env's KEY=value lines into every fish session
      # (iosta's shell — covers ssh logins, VSCode terminals, herdr panes, and
      # non-interactive `ssh guest cmd`, since fish sources /etc/fish/
      # config.fish for all of those). omp picks its API keys up from the
      # standard env vars (ANTHROPIC_API_KEY, OPENAI_API_KEY, …). Native fish
      # syntax on the fish-specific option — sh put into the generic
      # environment.shellInit would get babelfish-translated for fish at
      # build time, which can't translate sourcing a runtime sh file.
      programs.fish.shellInit = ''
        if test -r /run/agent.env
          for line in (grep -E '^[A-Za-z_][A-Za-z0-9_]*=' /run/agent.env)
            set -l kv (string split -m 1 = -- $line)
            set -gx $kv[1] $kv[2]
          end
        end

        # Forwarded ssh-agent (dev.tools.sandvm sets ForwardAgent for
        # sandvm-* hosts): pin SSH_AUTH_SOCK to a stable path. sshd mints a
        # fresh random /tmp socket per connection, so long-lived herdr panes
        # would otherwise hold a dead path after an ssh drop/reattach — each
        # new login re-points the symlink and every pane using the stable
        # path is live again. Sessions without a forwarded agent (console,
        # VSCode-remote terminals) adopt the symlink too when some ssh
        # session keeps it alive; with no ssh session connected, signing
        # requests just fail — key material never exists in the guest.
        if set -q SSH_AUTH_SOCK; and test "$SSH_AUTH_SOCK" != "$HOME/.ssh/agent.sock"; and test -S "$SSH_AUTH_SOCK"
          mkdir -p "$HOME/.ssh"
          ln -sf "$SSH_AUTH_SOCK" "$HOME/.ssh/agent.sock"
        end
        if test -S "$HOME/.ssh/agent.sock"
          set -gx SSH_AUTH_SOCK "$HOME/.ssh/agent.sock"
        end
      '';

      # git push/pull over the forwarded agent shouldn't stall on an
      # interactive host-key prompt (agents run non-interactively; the
      # ephemeral home also forgets accepted keys on every stop). GitHub's
      # published ed25519 key, from
      # https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
      programs.ssh.knownHosts."github.com".publicKey =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

      # Local LLM: abhaile's llama-server (services.llm, 127.0.0.1:8080) is
      # reachable from the guest at qemu's SLIRP gateway — 10.0.2.2 forwards
      # to the host's loopback. Pre-declare it as an omp provider; the model
      # ids and context sizes must match the llama-server router presets in
      # modules/den/aspects/services/llm.nix. Seeded with tmpfiles `C` (copy,
      # not symlink; only if absent) into iosta's ephemeral home so omp can
      # rewrite it at runtime and a fresh boot resets it.
      systemd.tmpfiles.rules =
        let
          # Only qwen: omp's own harness overhead (system prompt + tool
          # definitions) measured ~17.1k tokens, so llama-3.1-8b's 16k
          # server-side ctx-size 400s on every request — declaring it here
          # would just be a foot-gun (llama-server still serves it fine to
          # smaller-context clients; raising its ctx-size is an llm.nix
          # tuning decision, see TODO.md).
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
          # Parent dirs for sandvm-gitconfig's install (mirrors the host-side
          # secrets/home.nix tmpfiles layout for the same file).
          "d /home/iosta/.config 0755 iosta users - -"
          "d /home/iosta/.config/git 0700 iosta users - -"
        ];
    };
}
