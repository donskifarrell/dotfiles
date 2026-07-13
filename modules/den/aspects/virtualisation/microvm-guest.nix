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
  mem = lib.toIntBase10 (getEnvOr "MICROVM_MEM" "4096");
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

  # Same public key as modules/den/users/df.nix — it's public, safe to
  # duplicate; df's real private key/secrets never touch this guest (see
  # docs/microvm-sandbox.md, "what's not shared").
  authorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA6h5RafG9hYqgT3nviJO9P9eEUEAHJlIEqFWfoxFOP6";
in
{
  den.aspects.virtualization.microvm-guest.nixos =
    { pkgs, ... }:
    {
      imports = [ inputs.microvm.nixosModules.microvm ];

      # Agent harness — oh-my-pi, packaged as `omp` by numtide's nix-ai-tools
      # flake (not nixpkgs). Guest-only (unlike herdr, not wanted on the real
      # host) so it's a plain systemPackages entry here rather than routed
      # through roles.dev's home-manager packages like dev.tools.herdr is.
      environment.systemPackages = [
        inputs.nix-ai-tools.packages.${pkgs.system}.omp
      ];

      # Den sets networking.hostName from the static Den host name ("sandvm")
      # — mkForce so the per-launch instance name (e.g. the project's own
      # name) wins instead.
      networking.hostName = lib.mkForce vmName;

      microvm = {
        inherit vcpu mem;
        hypervisor = "qemu";

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
        ];

        # Cloud LLM API keys (optional): qemu reads the host file at VM start
        # and hands it to the guest's systemd as a system credential over
        # fw_cfg — contents never touch the /nix/store on either side. See
        # `sandvm-agent-env.service` below for the guest-side consumption.
        credentialFiles = lib.optionalAttrs (agentEnvFile != "") {
          AGENT_ENV = agentEnvFile;
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

      users.users.df.openssh.authorizedKeys.keys = [ authorizedKey ];

      # Console fallback: df/root have no password set (deliberately — SSH
      # pubkey is the intended path in), which meant a broken SSH connection
      # left the console login prompt with no usable credentials at all. A
      # typeable throwaway password instead of autologin (which was tried and
      # rejected — an auto-dropped-into shell on every launch was unwanted) —
      # same "throwaway creds" pattern as virtualisation/vm-login.nix's debug
      # VM. Not a security regression: the console is qemu's own stdout, only
      # ever reachable by whoever can already read the `sandvm`-launching
      # systemd-run unit (df on the host) — the same principal SSH already
      # trusts.
      users.users.df.initialPassword = "df";

      # --- LLM access for the agent harness (omp) ---

      # Cloud keys: install the AGENT_ENV system credential (if the launch
      # passed one — see microvm.credentialFiles above) where df's shells can
      # read it. /run is tmpfs, so like everything else in the guest it
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
            install -m 0600 -o df -g users \
              "$CREDENTIALS_DIRECTORY/AGENT_ENV" /run/agent.env
          fi
        '';
      };

      # Export /run/agent.env's KEY=value lines into every fish session (df's
      # shell — covers ssh logins, VSCode terminals, herdr panes, and
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
      '';

      # Local LLM: abhaile's llama-server (services.llm, 127.0.0.1:8080) is
      # reachable from the guest at qemu's SLIRP gateway — 10.0.2.2 forwards
      # to the host's loopback. Pre-declare it as an omp provider; the model
      # ids and context sizes must match the llama-server router presets in
      # modules/den/aspects/services/llm.nix. Seeded with tmpfiles `C` (copy,
      # not symlink; only if absent) into df's ephemeral home so omp can
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
                    contextWindow: 32768
                    maxTokens: 8192
          '';
        in
        [
          "d /home/df/.omp 0755 df users - -"
          "d /home/df/.omp/agent 0755 df users - -"
          "C /home/df/.omp/agent/models.yml 0644 df users - ${ompModels}"
        ];
    };
}
