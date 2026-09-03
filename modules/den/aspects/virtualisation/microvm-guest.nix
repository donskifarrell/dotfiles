# Guest-side shape of a `scoite` sandbox — see modules/den/hosts/scoite.nix for
# the four hosts that carry this aspect (one per sandbox type) and
# docs/microvm-sandbox.md for the full picture (why virtiofs for /workspace,
# why the SSH host key is shared not generated per-boot, what's deliberately
# NOT shared).
#
# Everything read impurely below (`builtins.getEnv`, set by the `scoite` CLI)
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
      lib.warn "MICROVM_WORKDIR unset — sharing /var/empty as /workspace. Launch via the `scoite` command (pkgs/by-name/scoite), not `nix run`/`nix build` directly." "/var/empty"
    else
      workdirRaw;

  sshPort = lib.toIntBase10 (getEnvOr "MICROVM_SSH_PORT" "2222");
  vcpu = lib.toIntBase10 (getEnvOr "MICROVM_CPU" "4");
  mem = lib.toIntBase10 (getEnvOr "MICROVM_MEM" "32768");

  # Volume sizes (MiB). Both images are sparse files that only cost host disk
  # as the guest actually writes into them, and both are grown in place by
  # `scoite resize` (truncate + QMP block_resize + the boot-time grow-fs unit
  # below), so these are generous ceilings rather than reservations.
  diskMib = lib.toIntBase10 (getEnvOr "MICROVM_DISK" "32768");
  homeMib = lib.toIntBase10 (getEnvOr "MICROVM_HOME_DISK" "16384");

  # Per-instance MAC for the bridge NIC, derived from the instance name by the
  # CLI (`mac_for`). It MUST be unique per instance — every guest sits on the
  # same host bridge, and two sandboxes sharing a MAC take each other's
  # traffic. Empty (a pure eval, e.g. `nix flake check`) falls back to a
  # locally-administered address that no launch ever uses.
  bridgeMac = getEnvOr "MICROVM_BR_MAC" "02:5c:00:00:00:01";

  extraPorts =
    let
      raw = builtins.getEnv "MICROVM_PORTS";
    in
    map lib.toIntBase10 (lib.filter (s: s != "") (lib.splitString "," raw));

  # Host-side bind address for every forwarded port. The CLI allocates one
  # 127.x.y.1 per instance (see `free_addr` in pkgs/by-name/scoite), which is
  # what lets guest ports map 1:1 — a guest's :8080 lands on 127.x.y.1:8080
  # and so cannot collide with abhaile's own llama-server on 127.0.0.1:8080,
  # nor with any other sandbox. It also keeps forwards genuinely host-only:
  # microvm.nix defaults `host.address` to "", which qemu renders as "bind all
  # interfaces" — every sandbox's ports (ssh included) were being offered to
  # the LAN, contradicting the host-only design in docs/microvm-sandbox.md.
  hostAddr = getEnvOr "MICROVM_HOST_ADDR" "127.0.0.1";

  # MICROVM_PORTS already carries the full effective set — the CLI's default
  # dev-port list plus any `--port`, minus whatever the host currently holds on
  # a wildcard address (see `effective_ports` in pkgs/by-name/scoite). That
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
    # ~/.config/scoite/agent.env + the omp auth-broker token: KEY=value lines
    # exported into every guest shell.
    AGENT_ENV = builtins.getEnv "MICROVM_AGENT_ENV";
    # df's ~/.config/git/gitconfig.local (a sops secret on the host):
    # user.name/user.email, no key material.
    GITCONFIG_LOCAL = builtins.getEnv "MICROVM_GITCONFIG";
    # df's live claude-code OAuth credential, refreshed into the guest on
    # every launch so a sandbox never has to run `claude login` of its own.
    CLAUDE_CREDS = builtins.getEnv "MICROVM_CLAUDE_CREDS";
    # A tar of df's ~/.ssh/sshconfig.local (the per-account
    # <acct>.github.com aliases, a sops secret on the host) plus the
    # *public* halves of the keys it names. No private key material: ssh
    # resolves an IdentityFile whose private half is missing against the
    # forwarded agent, which is what keeps per-account identity selection
    # working with the keys still on abhaile. See scoite-ssh-config below.
    SSH_CONF = builtins.getEnv "MICROVM_SSH_CONF";
    # A file holding the instance name — the one genuinely per-instance
    # *guest-visible* fact. Delivered as a credential rather than baked into
    # networking.hostName so the system closure stays identical across
    # instances. (credentialFiles values are paths, never inline values.)
    INSTANCE = builtins.getEnv "MICROVM_INSTANCE_FILE";
    # "<slot> <guest path>" lines: where to bind each /mnt/host/<slot> share.
    # Absent when the instance has no binds (see bindSlots above).
    BINDS = builtins.getEnv "MICROVM_BINDS_FILE";
  };

  # The *configuration* half of df's ~/.omp/agent, staged per instance by the
  # CLI (config*.yml and the agents/skills/rules/prompt trees — never the
  # sqlite stores, sessions, logs or the broker token).
  #
  # A 9p share, NOT a fw_cfg credential like the others (changed 2026-08-26):
  # systemd refuses to import a credential larger than 1 MiB, and df's
  # skills-vendor tree alone took the tar to 1.3 MiB — at which point the
  # credential vanished *silently*, the installer found nothing, and every new
  # sandbox came up with an empty ~/.omp. A share has no such ceiling, and it
  # is live: re-staging on the host is visible in the guest immediately, so
  # `scoite creds` only has to re-run the copy.
  ompConfDir = builtins.getEnv "MICROVM_OMP_CONF_DIR";

  # `scoite bind`: extra host folders, passed through as virtiofs exactly the
  # way /workspace is (real host uid/gid, so a host dir owned by df is
  # read-write to the guest's uid-1000 iosta).
  #
  # A *fixed* number of slots at *fixed* mount points, because a share's
  # `mountPoint` lands in `system.build.toplevel` while its `source` does not
  # (nixos-modules/microvm/mounts.nix renders only tag/proto/mountPoint into
  # `fileSystems`). Slots therefore keep every instance of a tier on one
  # system closure — the invariant this whole aspect is built around — and the
  # two genuinely per-instance halves travel the way per-instance data always
  # travels here: the host paths never reach the guest at all (they are
  # virtiofsd's `--shared-dir`, set by the CLI), and the guest-side
  # destinations arrive as the BINDS credential, applied by
  # scoite-binds.service below.
  #
  # `source` is a placeholder for the same reason: the CLI starts every
  # virtiofsd itself (see `boot` in pkgs/by-name/scoite/package.nix), so the
  # only thing qemu takes from a virtiofs share is its socket path. Slots an
  # instance does not use still get a daemon — qemu refuses to start when a
  # declared vhost-user socket is missing — pointed at an empty read-only
  # placeholder. Raising bindSlots means changing BIND_SLOTS in the CLI too.
  bindSlots = 4;

  # GitHub's published ed25519 host key. Consumed twice below — by the ssh
  # CLI (programs.ssh.knownHosts) and by iosta's *own* ~/.ssh/known_hosts —
  # because those are two different files and only one of them is enough for
  # each consumer. See the seeding rule in systemd.tmpfiles.rules.
  githubHostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
in
{
  den.aspects.virtualization.microvm-guest.nixos =
    { pkgs, ... }:
    let
      omp = inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.omp;

      # abhaile's llama-server (services.llm, 127.0.0.1:8080) is reachable from
      # a guest at qemu's SLIRP gateway, so pre-declare it as omp's `local`
      # provider. Model ids and context windows are GENERATED from
      # ../services/_llm-models.nix — the same file llama-server's router
      # presets come from — because the two used to be kept in step by hand and
      # a mismatch is invisible until a request hangs.
      #
      # The list is built as its own string and interpolated whole, rather than
      # `${...}` inside the indented block: Nix strips the *common* indentation
      # of a `''` string, and an interpolation sitting at a shallower indent
      # than its surroundings drags every generated line to column 0. That is
      # exactly what happened between 2026-08-25 and 2026-08-26 — the file's
      # list items lost their indentation and omp refused it with a yaml parse
      # error. Any change here: re-read the built file, do not eyeball the Nix.
      ompModels =
        let
          llm = import ../services/_llm-models.nix;
          usable = lib.filter (m: m.omp) llm.models;
          entries = lib.concatMapStringsSep "\n" (m: ''
            ${"      "}- id: ${m.id}
            ${"        "}name: ${m.name}
            ${"        "}contextWindow: ${toString m.ctx}
            ${"        "}maxTokens: ${toString m.maxTokens}'') usable;
        in
        pkgs.writeText "omp-models.yml" ''
          providers:
            local:
              baseUrl: ${llm.guestBaseUrl}
              auth: none
              api: openai-completions
              models:
          ${entries}
        '';

      # Host-identity installers. Each is used twice — from the boot unit that
      # reads the fw_cfg credential, and from `scoite creds`, which re-pushes
      # the same file into an already-running guest (TASKS.md S13/S14) — so
      # they are commands, not inline unit scripts.
      #
      # The units below call them by **absolute store path**: a systemd unit's
      # PATH does not include /run/current-system/sw/bin, and referring to them
      # by name failed at boot with "command not found" while the (login-shell)
      # push path kept working — silent, and exactly the kind of half-working
      # that looks fine in testing.
      installSshConf = pkgs.writeShellApplication {
        name = "scoite-install-ssh-conf";
        runtimeInputs = [
          pkgs.gnutar
          pkgs.coreutils
        ];
        text = ''
          src=''${1:?usage: scoite-install-ssh-conf <tar>}
          [ -f "$src" ] || exit 0

          install -d -m 0700 -o iosta -g users /home/iosta/.ssh
          # config.d is scoite's alone, so wiping it each time is how a
          # block df deleted on the host stops applying in the guest.
          rm -rf /home/iosta/.ssh/config.d
          install -d -m 0755 -o root -g root /home/iosta/.ssh/config.d
          tar -xf "$src" -C /home/iosta/.ssh
          # --no-dereference: ~/.ssh also holds the agent.sock symlink the
          # login shell maintains; never chase it out of the home.
          chown -R --no-dereference iosta:users /home/iosta/.ssh
          # Re-assert modes the tar would otherwise dictate. The included
          # config is root-owned on purpose: /etc/ssh/ssh_config parses
          # Include eagerly even for a user the Match doesn't apply to, and
          # ssh refuses a config file owned by neither root nor the caller —
          # iosta-owned, it broke root's ssh entirely with "Bad owner or
          # permissions". Root-owned + 0644 satisfies both users.
          chmod 0700 /home/iosta/.ssh
          chown -R root:root /home/iosta/.ssh/config.d
          chmod 0755 /home/iosta/.ssh/config.d
          chmod 0644 /home/iosta/.ssh/config.d/* || true
          chmod 0644 /home/iosta/.ssh/*.pub || true
        '';
      };

      installOmpConf = pkgs.writeShellApplication {
        name = "scoite-install-omp-conf";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.findutils
        ];
        text = ''
          src=''${1:-/run/scoite-omp}

          install -d -m 0755 -o iosta -g users /home/iosta/.omp
          install -d -m 0755 -o iosta -g users /home/iosta/.omp/agent

          # `local` provider, generated from
          # modules/den/aspects/services/_llm-models.nix — the same file
          # llama-server's router presets come from. Written on **every** run,
          # not seeded once: it is derived config, a stale or truncated copy
          # makes omp fail with a yaml parse error, and the previous
          # copy-if-absent tmpfiles rule meant a guest kept whatever it first
          # got, bad file included.
          install -m 0644 -o iosta -g users ${ompModels} \
            /home/iosta/.omp/agent/models.yml

          if [ -d "$src" ]; then
            # -T so the *contents* land in agent/, not a nested directory;
            # --no-preserve=mode because the source is a 9p share of a
            # host-staged tree.
            cp -a --no-preserve=mode -T "$src" /home/iosta/.omp/agent
            chown -R iosta:users /home/iosta/.omp
            echo "scoite: installed omp config ($(find "$src" -type f | wc -l) files from $src)"
          else
            echo "scoite: no omp config staged at $src - guest keeps models.yml only" >&2
          fi

          # Straight to the prompt, no onboarding (df, 2026-08-26). omp runs
          # its wizard when `startup.setupWizard` is true, and separately when
          # the stored setupVersion is behind CURRENT_SETUP_VERSION (2 in
          # omp 17.4.2) — set both, in the guest's copy only, using omp's own
          # writer so the yaml stays valid. The *real* omp, not the sandbox
          # wrapper: `--config` overlays must not be what gets written.
          runuser -u iosta -- env HOME=/home/iosta \
            ${omp}/bin/omp config set startup.setupWizard false >/dev/null 2>&1 || true
          runuser -u iosta -- env HOME=/home/iosta \
            ${omp}/bin/omp config set setupVersion 2 >/dev/null 2>&1 || true
        '';
      };

      installGitconfig = pkgs.writeShellApplication {
        name = "scoite-install-gitconfig";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          src=''${1:?usage: scoite-install-gitconfig <file>}
          [ -f "$src" ] || exit 0
          install -d -m 0755 -o iosta -g users /home/iosta/.config
          install -d -m 0700 -o iosta -g users /home/iosta/.config/git
          install -m 0600 -o iosta -g users "$src" \
            /home/iosta/.config/git/gitconfig.local
        '';
      };
    in
    {
      imports = [ inputs.microvm.nixosModules.microvm ];

      # Guest networking: systemd-networkd, one .network file per NIC.
      # roles.default ships no NetworkManager (2026-07-14) — a desktop network
      # daemon was the single biggest guest boot-time/RAM cost.
      networking.useNetworkd = true;
      systemd.network.wait-online.anyInterface = true;

      # eth0/eth1 instead of enp0s8/enp0s9: with two NICs the *only* thing
      # that reliably distinguishes them at build time is their order, and
      # kernel names follow that order while predictable names follow PCI
      # slots that microvm.nix may renumber. The MAC can't be matched on
      # either — the bridge one is per-instance and this closure is shared.
      networking.usePredictableInterfaceNames = false;

      systemd.network.networks = {
        "10-scoite-slirp" = {
          matchConfig.Name = "eth0";
          networkConfig.DHCP = "yes";
          # Lowest metric: this is the way out.
          dhcpV4Config.RouteMetric = 100;
        };

        "10-scoite-bridge" = {
          matchConfig.Name = "eth1";
          networkConfig = {
            DHCP = "ipv4";
            # Announce `<hostname>.local` on the bridge and answer queries for
            # it (TASKS.md S9). systemd-resolved does the publishing, so no
            # avahi in the guest.
            MulticastDNS = true;
          };
          dhcpV4Config = {
            # Identify by MAC, not by the default DUID: networkd derives that
            # DUID from /etc/machine-id, every guest of a type shares one
            # system closure and therefore one machine-id, and dnsmasq
            # (correctly) then hands every sandbox the *same* lease — two
            # running guests both answering on 10.77.0.106. The MAC is the one
            # per-instance thing this NIC has.
            ClientIdentifier = "mac";

            # Address only. A default route here would race SLIRP's for
            # egress, and the bridge's dnsmasq runs with `port=0` — it serves
            # no DNS to take.
            UseRoutes = false;
            UseDNS = false;
            UseNTP = false;
            # The guest's hostname comes from the INSTANCE credential, not
            # from a DHCP lease.
            UseHostname = false;
          };
        };
      };

      # resolved is what answers/publishes mDNS above; it is not a resolver
      # change for anything else (SLIRP's DNS still comes over eth0).
      services.resolved = {
        enable = true;
        # `services.resolved.llmnr` was renamed on the way to the settings
        # freeform (it still works, but warns on every guest build).
        settings.Resolve.LLMNR = "false";
      };

      # No firewall in the guest, deliberately. SLIRP gives a sandbox exactly
      # one inbound path — a `hostfwd` rule held by qemu on the host — so the
      # forwardPorts list below *is* the access-control list; an in-guest
      # firewall only adds a second, invisible one that has to be kept in sync
      # with it. Nothing here used to set this, so guests ran NixOS's default:
      # enabled, port 22 only (from services.openssh.openFirewall), policy
      # DROP. That silently black-holed every `scoite --port N` — the host-side
      # connect succeeded (qemu accepts on the host side before it dials the
      # guest), the request then hit a DROP with no RST, and curl hung forever
      # with no error anywhere. Ports nothing forwards stay unreachable for the
      # solid reason that qemu is not listening on them.
      networking.firewall.enable = false;

      # Static, deliberately: Den would derive this from the Den host name
      # ("scoite-devenv", …) and the previous design forced it to the
      # per-launch instance name — which put the instance name inside
      # /etc and so gave every sandbox its own system closure. The real
      # hostname is set at boot from the INSTANCE credential by
      # scoite-hostname.service below.
      networking.hostName = lib.mkForce "sandbox";

      microvm = {
        inherit vcpu mem;
        hypervisor = "qemu";

        # Big ceiling, small footprint: qemu allocates guest RAM lazily (only
        # pages the guest touches cost host memory), and microvm.nix's qemu
        # runner wires this balloon with free-page-reporting=on — freed guest
        # pages are returned to the host automatically, no QMP babysitting.
        balloon = true;

        # Two NICs, on purpose (2026-08-25, TASKS.md S8):
        #
        #   eth0  qemu SLIRP. Keeps the *default route* and with it every
        #         outbound path a sandbox has ever had, including abhaile's
        #         loopback services at the SLIRP gateway 10.0.2.2
        #         (llama-server :8080, omp auth-broker :8765, harmonia :5000).
        #         Its inbound side is still only what the CLI forwards.
        #   eth1  a tap on the host bridge `scoitebr0`
        #         (virtualisation/microvm-host.nix), attached by qemu's setuid
        #         bridge helper so an unprivileged `scoite` can do it. This is
        #         what gives a guest a real address the host can reach without
        #         a forward — the precondition for mDNS names (S9) and LAN
        #         exposure (S11). It takes an address from the bridge's dnsmasq
        #         and nothing else: no default route, no DNS (see the .network
        #         files below).
        #
        # The SLIRP MAC is shared by every instance and always was — SLIRP is a
        # per-VM userspace stack, so nothing else can see it. The bridge MAC
        # cannot be shared, hence the per-launch value.
        interfaces = [
          {
            type = "user";
            id = "usernet0";
            mac = "02:00:00:01:01:01";
          }
          {
            type = "bridge";
            id = "brnet0";
            mac = bridgeMac;
            bridge = "scoitebr0";
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
            source = "/var/lib/scoite/hostkey";
            mountPoint = "/etc/scoite-hostkey";
          }
        ]
        ++ lib.optional (ompConfDir != "") {
          tag = "ompconf";
          source = ompConfDir;
          mountPoint = "/run/scoite-omp";
        }
        ++ map (i: {
          tag = "bind${toString i}";
          proto = "virtiofs";
          # Placeholder, deliberately: the real host directory is virtiofsd's
          # --shared-dir and never enters this eval (see bindSlots).
          source = "/var/empty";
          mountPoint = "/mnt/host/${toString i}";
        }) (lib.range 0 (bindSlots - 1));

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
          # all survive stop→start, and `scoite rm` is what throws them away.
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
          path = "/etc/scoite-hostkey/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];

      # VSCode Remote-SSH (`code --remote ssh-remote+scoite-<name> /workspace`):
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
      # `scoite`-launching systemd-run unit.
      users.users.iosta.initialPassword = "iosta";

      # --- per-instance boot wiring ----------------------------------------

      # The instance's real name, from the fw_cfg credential (see the comment
      # on networking.hostName above).
      systemd.services.scoite-hostname = {
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
      systemd.services.scoite-home-perms = {
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

      # `scoite bind`: put each host folder the CLI shared this launch where
      # the instance asked for it. The shares themselves are the fixed
      # /mnt/host/<slot> mounts (see bindSlots); this is the per-instance half,
      # and it is a bind mount rather than a symlink so the destination is a
      # real directory to anything that inspects it (`realpath`, a config
      # loader that rejects symlinks, an editor watching for renames).
      #
      # Ordered before the two things that would otherwise observe an
      # unpopulated destination: home-manager activation and the first login.
      # Failures are per-entry and never fatal — a sandbox must still boot with
      # a bind it cannot satisfy, or a typo'd destination would cost a
      # reachable machine.
      systemd.services.scoite-binds = {
        description = "Bind host folders shared by `scoite bind` into place";
        wantedBy = [ "multi-user.target" ];
        after = [
          "local-fs.target"
          "scoite-home-perms.service"
        ];
        before = [
          "home-manager-iosta.service"
          "sshd.service"
        ];
        unitConfig.RequiresMountsFor = map (i: "/mnt/host/${toString i}") (lib.range 0 (bindSlots - 1));
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ImportCredential = "BINDS";
        };
        path = [ pkgs.util-linux ];
        script = ''
          creds=''${CREDENTIALS_DIRECTORY:-}
          [ -n "$creds" ] && [ -s "$creds/BINDS" ] || exit 0

          while read -r slot dest; do
            [ -n "''${slot:-}" ] && [ -n "''${dest:-}" ] || continue
            src=/mnt/host/$slot

            case "$dest" in
              /*) ;;
              *) echo "scoite-binds: '$dest' is not an absolute path - skipped"; continue ;;
            esac
            if ! mountpoint -q "$src"; then
              echo "scoite-binds: $src is not mounted - $dest skipped"
              continue
            fi
            if mountpoint -q "$dest"; then continue; fi
            if [ -e "$dest" ] && [ ! -d "$dest" ]; then
              echo "scoite-binds: $dest exists and is not a directory - skipped"
              continue
            fi

            mkdir -p "$dest" || { echo "scoite-binds: cannot create $dest"; continue; }
            # Only for a fresh mountpoint inside iosta's home: after the bind
            # the guest sees the *host* directory's ownership, which lands on
            # iosta anyway (uid 1000 both sides).
            case "$dest" in
              /home/iosta/*) chown iosta:users "$dest" || true ;;
            esac

            if mount --bind "$src" "$dest"; then
              echo "scoite-binds: $dest <- host bind slot $slot"
            else
              echo "scoite-binds: could not bind $src onto $dest"
            fi
          done < "$creds/BINDS"
        '';
      };

      # "Expand in size as needed": `scoite resize` grows the backing image on
      # the host and, for a running guest, the virtio-blk device via QMP. This
      # stretches the filesystem onto whatever space the device now has.
      # Online resize2fs on a mounted ext4 is a fast no-op when the fs already
      # fills its device, which is what lets this run both at boot (picking up
      # a resize done while stopped) and on a timer (picking up a live one)
      # without any host->guest signalling channel.
      systemd.services.scoite-grow-fs = {
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

      systemd.timers.scoite-grow-fs = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "2min";
          OnUnitActiveSec = "2min";
        };
      };

      # Cloud LLM keys: install the AGENT_ENV credential where iosta's shells
      # can read it. /run is tmpfs, so it evaporates on stop.
      systemd.services.scoite-agent-env = {
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
      systemd.services.scoite-omp-conf = {
        wantedBy = [ "multi-user.target" ];
        # The config arrives on a 9p share now, not as a credential, so this
        # waits for the mount rather than importing anything.
        after = [
          "scoite-home-perms.service"
          "run-scoite\\x2domp.mount"
        ];
        unitConfig.RequiresMountsFor = "/run/scoite-omp";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        path = [ pkgs.util-linux ]; # runuser
        script = ''
          ${lib.getExe installOmpConf} /run/scoite-omp
        '';
      };

      systemd.services.scoite-gitconfig = {
        wantedBy = [ "multi-user.target" ];
        after = [ "scoite-home-perms.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ImportCredential = "GITCONFIG_LOCAL";
        };
        script = ''
          ${lib.getExe installGitconfig} "$CREDENTIALS_DIRECTORY/GITCONFIG_LOCAL" || true
        '';
      };

      # GitHub ssh aliases: install the SSH_CONF credential so a remote like
      # git@donskifarrell.github.com:… resolves in the guest and picks the
      # right account's key out of the forwarded agent. Public halves only —
      # the tar is built by `collect_credentials` in pkgs/by-name/scoite and
      # deliberately never touches a private key.
      # Installed as a *command*, not inlined in the unit below, because the
      # same work has to happen twice: once at boot from the fw_cfg
      # credential, and again whenever `scoite creds` re-pushes a changed
      # ~/.ssh/sshconfig.local into an already-running guest (TASKS.md S13).
      # Also on PATH: `scoite creds` runs them through a login shell.
      environment.systemPackages = [
        installSshConf
        installOmpConf
        installGitconfig
      ];

      systemd.services.scoite-ssh-config = {
        wantedBy = [ "multi-user.target" ];
        after = [ "scoite-home-perms.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ImportCredential = "SSH_CONF";
        };
        script = ''
          ${lib.getExe installSshConf} "$CREDENTIALS_DIRECTORY/SSH_CONF" || true
        '';
      };

      # claude-code's own OAuth credential, copied from the host on every
      # launch (df's decision, 2026-08-22: zero-touch beats one `claude login`
      # per instance). It is refreshed each launch rather than left to age in
      # the persistent home, so a sandbox that has been stopped for a week
      # still starts with a live token. This *is* a real credential inside the
      # sandbox — see docs/microvm-sandbox.md, "What's deliberately NOT
      # shared", for why that trade was accepted and what it exposes.
      systemd.services.scoite-claude-creds = {
        wantedBy = [ "multi-user.target" ];
        after = [ "scoite-home-perms.service" ];
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
      systemd.services.scoite-workspace-init = {
        description = "Pre-install /workspace project dependencies (devenv/flake)";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [
          "network-online.target"
          "scoite-grow-fs.service"
          # direnv's whitelist (roles.sandbox.dev sets whitelist.prefix =
          # ["/workspace"]) is a home-manager file: without this the pre-build
          # can run before ~/.config/direnv/direnv.toml exists and direnv
          # blocks the .envrc it was launched to evaluate.
          "home-manager-iosta.service"
        ];
        unitConfig.ConditionPathIsDirectory = "/workspace";
        path = [
          pkgs.devenv
          pkgs.direnv
          pkgs.git
          pkgs.nix
          # A project's devenv can shell out to privileged helpers — mono's
          # caddy task runs `sudo setcap` — and a systemd unit's PATH has
          # neither /run/wrappers/bin nor /run/current-system/sw/bin.
          "/run/wrappers"
          "/run/current-system/sw"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "iosta";
          Group = "users";
          WorkingDirectory = "/workspace";
        };
        # `.envrc` first: it is the entry point a shell will actually use, and
        # it can point anywhere (`use flake`, `use devenv`, `layout python`, a
        # hand-written PATH). Building *it* pre-populates direnv's cache, so
        # the first interactive shell in /workspace is instant instead of
        # spending a minute in a cold evaluation. devenv.nix/flake.nix are the
        # fallbacks for a project that has one but no .envrc.
        #
        # Failures are NOT swallowed (they were until 2026-08-24): nothing
        # else orders after this unit, so letting it fail costs the guest
        # nothing and makes a broken project environment visible in
        # `systemctl status scoite-workspace-init` instead of scrolling past
        # in the boot log.
        script = ''
          if [ -f .envrc ]; then
            echo "/workspace/.envrc found - loading it with direnv"
            direnv exec /workspace true
          elif [ -f devenv.nix ] && command -v devenv >/dev/null; then
            echo "devenv.nix found - building the devenv environment"
            devenv shell true
          elif [ -f flake.nix ]; then
            echo "flake.nix found - building the flake devShell"
            nix develop --command true
          fi
        '';
      };

      # Land every session in /workspace, not in $HOME — that is the only
      # thing a sandbox exists to work on. loginShellInit runs before
      # interactiveShellInit, so anything an interactive shell starts inherits
      # the directory too.
      #
      # The wait is not politeness, it is correctness: scoite-workspace-init is
      # already evaluating this project's devenv/flake at boot, and direnv (in
      # interactiveShellInit, right after this block) would start a **second**
      # evaluation of the same project on the same shared /workspace. Two
      # concurrent devenv bootstraps writing the same `.devenv/` fail — seen
      # 2026-08-26 on a `scoite new --ssh` into a big monorepo: the pre-build
      # took four minutes, the login raced it, and devenv died with "Failed to
      # get shell attribute" inside a nixpkgs-bootstrap trace. Waiting also
      # means the shell you get has the environment ready rather than paying
      # for it again.
      programs.fish.loginShellInit = ''
        if test -d /workspace
          if test (systemctl show scoite-workspace-init.service -p ActiveState --value 2>/dev/null) = activating
            echo "scoite: waiting for the project environment pre-build (scoite-workspace-init)…"
            # Bounded: a wedged pre-build must not make the sandbox
            # unreachable. 20 minutes, then carry on regardless.
            # `_` is read-only in fish 4.x (it holds the current command
            # name) — a loop variable named `_` aborts config.fish parsing.
            for _i in (seq 1200)
              test (systemctl show scoite-workspace-init.service -p ActiveState --value 2>/dev/null) = activating
              or break
              sleep 1
            end
          end
          if test "$PWD" = "$HOME"
            cd /workspace
          end
        end
      '';

      # Export /run/agent.env's KEY=value lines into every fish session
      # (covers ssh logins, VSCode terminals, and non-interactive
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

        # Forwarded ssh-agent (dev.tools.scoite sets ForwardAgent for scoite-*
        # hosts): pin SSH_AUTH_SOCK to a stable path. sshd mints a fresh
        # random socket per connection, so long-lived guest sessions would
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
      # interactive host-key prompt. GitHub's published ed25519 key — it
      # covers the <acct>.github.com aliases too, since those carry
      # `HostName github.com` and ssh checks the key against that.
      programs.ssh.knownHosts."github.com".publicKey = githubHostKey;

      # Pick up what scoite-ssh-config drops in. NixOS renders extraConfig
      # first in /etc/ssh/ssh_config, and ssh_config is first-match-wins, so
      # these blocks beat any default that follows. Mirrors the host-side
      # include in core/network/ssh.nix, with two syntax constraints of the
      # system-wide file: `~` is rejected there ("bad include path"), so the
      # path is absolute and therefore scoped to iosta with `Match localuser`;
      # and that Match has to be closed by a `Host *` or it would swallow every
      # generated directive below it. A glob matching nothing is ignored, so a
      # guest launched without the credential is unaffected.
      programs.ssh.extraConfig = ''
        Match localuser iosta
          Include /home/iosta/.ssh/config.d/*
        Host *
      '';

      # The omp config directory itself; its *contents* (models.yml and
      # whatever the host staged) are installed by scoite-omp-conf.service.
      #
      # Plus iosta's own known_hosts (2026-08-28). The pin above only reaches
      # /etc/ssh/ssh_known_hosts, which the ssh *CLI* reads — libgit2 doesn't:
      # it checks ~/.ssh/known_hosts and nothing else. That matters because
      # df's gitconfig (pushed in by `scoite creds`) carries
      # `url."git@github.com:".insteadOf = "https://github.com/"`, so nix
      # rewrites every github: flake input to ssh before libgit2 dials it —
      # and with no ~/.ssh/known_hosts libgit2 fails the host-key check and
      # reports it as `connecting to remote 'https://…': invalid or unknown
      # remote ssh hostkey`, which reads like a TLS/CA problem and isn't one.
      # `devenv update` in a guest could not lock a single input before this.
      #
      # `C` copies only when the destination is absent, so a host iosta
      # accepts later still gets appended and survives the next boot.
      systemd.tmpfiles.rules = [
        "d /home/iosta/.omp 0755 iosta users - -"
        "d /home/iosta/.omp/agent 0755 iosta users - -"
        "d /home/iosta/.ssh 0700 iosta users - -"
        "C /home/iosta/.ssh/known_hosts 0600 iosta users - ${pkgs.writeText "scoite-known-hosts" "github.com ${githubHostKey}\n"}"
      ];
    };
}
