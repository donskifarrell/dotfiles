# `sandvm` — per-folder sandboxed microVMs for coding agents

## What this is

`sandvm <path>` boots a throwaway NixOS microVM (microvm.nix, qemu) whose _only_ writable channel back to the host
filesystem is `<path>`, mounted at `/workspace`. It exists so a coding-agent harness (oh-my-pi, packaged as `omp`) can
run against a real project with a real dev toolchain (devenv.sh, direnv, git, a full TUI shell config, herdr for session
management) without being able to write — or even see — anything outside that one folder, even if the agent or the LLM
behind it goes rogue.

## Usage

```
sandvm [--port N ...] [--cpu N] [--mem N] [-f|--foreground] [<path>]   # default <path>: $PWD
sandvm stop [<name>]                                                    # default: current dir's
sandvm rm [<name>]                                                      # stop + delete state (irreversible)
sandvm list
```

`sandvm` runs detached in the background by default (it's a `systemd-run --user --unit` transient service running
`virtiofsd-run` and `microvm-run` from the `nix build --impure .#sandvm-guest` result) and returns control to the
terminal immediately — `sandvm stop` ends it, `journalctl --user -u sandvm-<name> -f` follows its console.
`-f`/`--foreground` instead blocks in the invoking terminal (Ctrl-C to stop), the original behavior. Fish completions
for subcommands/flags/known instance names ship in the package itself (`share/fish/vendor_completions.d`), so they're
live for `df` automatically — no separate wiring. It prints, on start:

```
sandvm 'myproject-a1b2c3d4' -> /home/df/dev/myproject
  ssh sandvm-myproject-a1b2c3d4
  code --remote ssh-remote+sandvm-myproject-a1b2c3d4 /workspace
```

The instance name is `basename(realpath(path))` + an 8-char hash of the realpath, so the same folder always maps to the
same name/SSH alias/port — relaunching after a stop reuses them; a renamed or moved folder gets a fresh identity (its
old sandbox, if still running, is untouched).

## Architecture

One Den "host", `sandvm` (`modules/den/hosts/sandvm.nix`), defines the guest shape once, statically. Three scalars are
runtime-parameterized via env vars (`MICROVM_WORKDIR`, `MICROVM_NAME`, `MICROVM_SSH_PORT`, `MICROVM_PORTS`,
`MICROVM_CPU`, `MICROVM_MEM`) and read with `builtins.getEnv` in `virtualization.microvm-guest` — the one deliberate bit
of impurity in the whole feature (hence `nix run --impure`). Everything else is ordinary static Nix, composed exactly
like a real host: `roles.default`, `roles.dev-sandbox`, and the guest user **`iosta`** (`users.iosta = { }`,
`modules/den/users/iosta.nix`) — a sandbox-only user, uid-pinned to 1000 to match the host-side project owner (df) for
the virtiofs `/workspace` share, carrying only `roles.dev-sandbox`. That role is role-workstation's TUI slice: the full
fish/starship/neovim/yazi/etc. shell config, git + lazygit + gh, devenv/direnv, herdr (the startup multiplexer —
deliberately not zellij) and the agent tools (claude-code, omp) — no browsers, no ghostty, no desktop packages.
(Originally the guest ran df's _full_ HM identity, workstation/desktop packages included; the lean iosta identity
replaced that on 2026-07-13.)

Two sandbox-specific behaviours are wired in on top:

- **herdr on startup**: interactive SSH logins `exec herdr` directly (`dev.tools.herdr.autostart` — fish init guarded on
  `SSH_TTY`, so the qemu serial console and VSCode-remote terminals stay plain fish, and on `HERDR_ENV`, so herdr's own
  panes don't recurse).
- **Dependency pre-install**: a boot-time oneshot (`sandvm-workspace-init`, in `microvm-guest.nix`, runs as iosta in
  `/workspace`) builds the project's declared toolchain — `devenv shell true` if `devenv.nix` exists, else
  `nix develop --command true` if `flake.nix` exists — so the environment is already in the persistent store overlay
  before anyone attaches; failures are logged, never fatal. Interactively, direnv whitelists `/workspace`
  (role-dev-sandbox), so a project `.envrc` activates without a manual `direnv allow` (allow-state would be lost with
  the ephemeral home on every boot anyway).

Files:

- `modules/den/aspects/virtualisation/microvm-host.nix` — host-side: just a persistent SSH host key at
  `/var/lib/sandvm/hostkey`, generated once via `system.activationScripts` (not left to the guest to generate per-boot,
  which would both churn `known_hosts` and race between concurrent instances' first boot).
- `modules/den/aspects/virtualisation/microvm-guest.nix` — guest-side: `microvm.shares`/`forwardPorts`/`interfaces`,
  sshd pointed at the shared host key, the console fallback password, the `sandvm-workspace-init` dependency
  pre-installer, the agent.env/omp wiring.
- `modules/den/users/iosta.nix` — the guest user aspect: uid 1000 (virtiofs), df's authorized key (public — see "What's
  deliberately not shared" below), includes `roles.dev-sandbox` and nothing else.
- `modules/den/roles/dev-sandbox.nix` — the TUI-only role iosta carries (shell config, git, devenv/direnv, herdr +
  autostart, agent tools; no graphical apps, no zellij).
- `modules/den/hosts/sandvm.nix` — the Den host declaration + the `packages.sandvm-guest` flake output
  (`nixosConfigurations.sandvm.config. microvm.declaredRunner`).
- `pkgs/by-name/sandvm/package.nix` — the CLI wrapper (name/port bookkeeping, `~/.ssh/config.d/sandvm`,
  `systemd-run --user --unit` lifecycle) plus `pkgs/by-name/sandvm/completions.fish`, merged into the same package
  output via `symlinkJoin` (`writeShellApplication`'s own `buildCommand` can't take a `postInstall`, since it bypasses
  `genericBuild`'s phases entirely — see the comment in package.nix).
- `modules/den/aspects/dev/tools/sandvm.nix` — installs the CLI onto df's `$PATH`, included via `roles.dev`.
- `modules/den/aspects/dev/vscode.nix` — not sandvm-specific, but load-bearing for it: df's editor carries the
  Remote-SSH extension, and `remote.SSH.configFile` must point at `~/.ssh/config` (see "VS Code Remote-SSH" below).
- `modules/den/aspects/dev/tools/herdr.nix` — installs herdr (herdr.dev — terminal multiplexer for coding-agent
  sessions, `nix-ai-tools`, not nixpkgs); included by `roles.dev` (abhaile's df) _and_ `roles.dev-sandbox` (the guest's
  iosta) — one aspect, no duplication. Also defines `dev.tools.herdr.autostart` (guest-only via the sandbox role): the
  fish snippet that lands interactive SSH logins straight in herdr. `herdr --remote sandvm-<name>` attaches from the
  host to a session running inside a guest, over the ssh alias `sandvm` itself sets up — herdr tunnels entirely over
  plain ssh, no daemon/server toggle needed on either end.
- `omp` (oh-my-pi, also `nix-ai-tools`) reaches the guest via `apps.ai-tools` in `roles.dev-sandbox` — the same aspect
  that installs omp + claude-code for df on real hosts (via `roles.workstation`), so one aspect covers both. (Until
  2026-07-14 `microvm-guest.nix` also carried a duplicate guest-only `environment.systemPackages` omp entry, with a
  comment wrongly claiming omp wasn't installed on real hosts.)

Named `sandvm`, not `devbox`: nixpkgs already has an unrelated package literally called `devbox` (Jetify's tool). Using
that name for `pkgs.devbox` in home-manager would have silently resolved to the wrong package — there's no overlay
merging this flake's own `pkgs/by-name` into the nixpkgs instance NixOS/HM modules see, so this flake's own packages
must be referenced via `inputs.self.packages.${system}.<name>`, not `pkgs.<name>`.

## The security boundary

microVMs only ever see the host filesystem through explicit `microvm.shares`. The guest gets exactly three:

- `/workspace` ← the project folder, **read-write**. The only writable channel back to the host's _actual_ files.
- `/nix/.ro-store` ← host's `/nix/store`, **read-only** (standard microvm.nix pattern; shrinks the guest closure/boot
  time — read-only content-addressed store paths aren't an escape vector).
- `/etc/sandvm-hostkey` ← the persistent SSH host key directory, read-write but containing nothing except that key.

Nothing else is shared from the real host filesystem. The guest also gets one writable _volume_ (not a share — an
auto-created disk image file, see "Why a writable store overlay" below) for `/nix/.rw-store`, living in the per-instance
state dir (`~/.local/state/sandvm/<name>/nix-store-overlay.img`) rather than anywhere on the real host filesystem, so it
doesn't weaken this boundary — it only ever holds new, content-addressed Nix store paths the guest builds/fetches for
itself, the same trust level as the read-only store share. It does persist across `sandvm stop`/ relaunch (so a
project's devenv toolchain doesn't need refetching every launch); the guest's actual root filesystem (`/`) stays
ephemeral tmpfs, discarded on stop. Even a fully compromised agent inside the guest cannot touch host files outside
`/workspace`, see df's `$HOME`, other projects, or secrets.

### Why a writable store overlay

Sharing the host's `/nix/store` read-only (above) means the guest's entire store starts out read-only — and microvm.nix
auto-disables `nix-daemon` in that case ("nix-daemon works only with a writable /nix/store"). That breaks two things:
home-manager activation (needs to write `/nix/var/nix`'s database) and, more importantly, **the actual point of putting
devenv.sh in the guest** — a project's own dependencies need to be installable at runtime, which means the guest needs
to be able to build/fetch new store paths for itself. `microvm.writableStoreOverlay` + a backing `microvm.volumes` entry
(an overlayfs upper layer; 9p/virtiofs shares can't serve as one, so it has to be a volume) is what makes that possible,
and re-enables `nix-daemon` as a side effect. Discovered by actually booting a guest and watching
`home-manager-df.service` fail with `creating directory "/nix/var/nix/temproots": Permission denied` — not something
visible from a `nix build` alone.

### Why `/workspace` is virtiofs but the others are 9p

`ro-store` and `hostkey` are **9p** (built into qemu, no companion process needed — simplest option, and fine since
they're read-mostly). `workspace` is **virtiofs**, and that wasn't the original design — discovered the hard way by
actually writing into a running guest's `/workspace` and hitting `Permission denied`. qemu's built-in 9p security models
(`none`, the default; also tried `mapped`) only assign correct guest-side ownership to files the _guest itself_ creates
through the share — a share of an **already-populated** directory (like a real project) presents every pre-existing
file, and the share's root directory itself, as owned by `root:root` to the guest, because qemu runs unprivileged (as
df, not root) and can't otherwise vouch for arbitrary ownership over 9p. Result: the guest user (uid 1000, matching the
host) couldn't write into its own project's share at all. virtiofsd passes through real host uid/gid directly instead of
trying to remap anything, which works here specifically because the guest user's uid matches the host-side project
owner's — this is exactly why `users/iosta.nix` pins `uid = 1000` instead of trusting NixOS's allocation.

The cost: virtiofs needs a separate `virtiofsd` process started as a prerequisite (`bin/virtiofsd-run`, bundled
alongside `bin/microvm-run` in the same `sandvm-guest` build once any share uses `proto = "virtiofs"`), and that
companion-process lifecycle normally only gets managed automatically under microvm.nix's systemd-managed
`microvm.host`/`microvm.vms.*` path, which `sandvm` deliberately doesn't use (see below) — so the `sandvm` wrapper
starts `virtiofsd-run` itself (backgrounded inside the same `systemd-run --user --unit`, so `sandvm stop` tears down
both together via the cgroup — `KillMode=control-group` is the default for transient service units, same as scopes) and
polls for its socket before handing off to `microvm-run`, since there's no `Type=notify` readiness wiring to lean on
outside the host-managed path.

### What's deliberately NOT shared into the guest

`secrets.home` (df's real SSH/git private keys) is **not** included in the guest's aspect list, and only df's _public_
key goes in, as iosta's authorized key (for inbound SSH — same literal as `modules/den/users/df.nix`, safe to duplicate;
the guest user has no key material of its own). The concern isn't just "the agent shouldn't write outside `/workspace`"
but that it shouldn't be able to _read and exfiltrate_ real credentials either, since it already has network access to
talk to an LLM. Outbound git push/pull auth works via SSH-agent **forwarding** instead (below) — the guest can ask the
host's agent to sign while a session is connected, but no private key ever exists on the guest side to exfiltrate.

One narrow exception (2026-07-19): `~/.config/git/gitconfig.local` — df's git _identity_ (user.name/user.email + the
includeIf org lines), a sops secret on the host — **is** handed into the guest, because without it commits fail with
"Author identity unknown" (the guest's git config includes that path via `dev.git`, but iosta's ephemeral home had no
such file). It travels the same route as agent.env — wrapper exports `MICROVM_GITCONFIG` when the host file exists,
`microvm.credentialFiles.GITCONFIG_LOCAL` hands it over via fw_cfg (never in the store), and the guest's
`sandvm-gitconfig` oneshot installs it to `/home/iosta/.config/git/gitconfig.local` (0600, ephemeral home — gone on
stop). It's name/email only — no key material; the org includeIf targets it references (`gitconfig.pgstar`, …) stay
absent in the guest and git silently skips missing includes, so sandbox commits always use the default identity.

## Git auth: SSH-agent forwarding (2026-07-13)

`ssh sandvm-<name>` forwards the host's ssh-agent (`services.ssh-agent`, the HM user service holding df's keys), so
`git push`/`pull`/`fetch` and `ssh -T git@github.com` just work inside a sandbox. Verified end-to-end: `ssh-add -l` in
the guest lists the host agent's keys, GitHub authenticates as df — with zero key files in the guest.

Three pieces, all small:

- **`ForwardAgent yes` for `Host sandvm-*`** — lives in `dev.tools.sandvm`'s homeManager module
  (`programs.ssh.settings."sandvm-*"`), **not** in the per-instance blocks the wrapper writes into `~/.ssh/config.d/`.
  That placement is load-bearing: `ssh_config` is first-match-wins per keyword, and `core.network.ssh`'s `Host *` block
  (`ForwardAgent no`) is rendered **before** the `Include ~/.ssh/config.d/*` line, so a `ForwardAgent` in the wrapper's
  file would be silently shadowed. Home-manager renders non-`"*"` settings blocks before the `"*"` default block, so the
  aspect-level `Host sandvm-*` wins. (HM-managed `~/.ssh/config` ⇒ takes effect on the next `nixos-rebuild switch`;
  until then `ssh -o ForwardAgent=yes sandvm-<name>` does the same thing.)
- **Stable socket path in the guest** (`microvm-guest.nix` fish shellInit): sshd mints a fresh random agent socket per
  connection, so a long-lived herdr pane would hold a dead `SSH_AUTH_SOCK` after an ssh drop + reattach. Every login
  re-points `~/.ssh/agent.sock` at its own live socket and sessions use the symlink — verified: kill the ssh
  ControlMaster, reconnect, panes' agent works again without restarting anything.
- **`github.com` in the guest's known_hosts** (`programs.ssh.knownHosts`, GitHub's published ed25519 key) — so a
  non-interactive agent's first `git fetch` can't stall on a host-key prompt (the ephemeral home would forget an
  accepted key on every stop anyway).

**Why not virtiofs?** TODO 7.4's original idea — "virtiofs can proxy a live UNIX socket" — was tested and is **false**:
a socket bound on the host inside the shared workspace shows up in the guest as a socket inode (`srwxr-xr-x`), but
`connect()` from the guest returns `ECONNREFUSED` and the host listener never sees a connection. virtiofs shares the
filesystem namespace only; socket _endpoints_ live in the kernel that bound them. Agent forwarding over the existing SSH
channel is the mechanism that actually works (vsock + socat would be the alternative if session-independent forwarding
were ever needed).

**Trade-off, stated plainly:** while (and only while) an ssh session with forwarding is connected, a rogue agent in the
guest can _use_ the host agent to authenticate as df (it can never _read_ the keys). That's the same trust tier as the
auth-broker/llama-server reachability above, and strictly better than key copies. `AddKeysToAgent = "confirm"` on the
host applies per-key as usual; for a sensitive key, `ssh-add -c` makes every signature require host-side confirmation.

## VS Code Remote-SSH (2026-07-13)

The launch banner's `code --remote ssh-remote+sandvm-<name> /workspace` line works for real now (equivalently: F1 →
"Remote-SSH: Connect to Host…" → `sandvm-<name>` → open `/workspace`) — a full editor session inside the sandbox, files
edited as if local, integrated terminals landing in the guest as iosta. Four pieces made it work:

- **Guest: `programs.nix-ld.enable`** (`microvm-guest.nix`). Remote-SSH downloads a prebuilt server into
  `~/.vscode-server` whose node binary is linked against `/lib64/ld-linux-x86-64.so.2` — a path that doesn't exist on
  NixOS, so the server died on launch. nix-ld provides that loader; no `NIX_LD` env plumbing is needed for sshd exec
  sessions (where profile sourcing is shaky) because nix-ld falls back to
  `/run/current-system/sw/share/nix-ld/lib/ld.so` when the var is unset. The bootstrap's download tooling (curl/wget,
  tar) was already in the guest via `shell.bundles.base` / the NixOS base path.
- **Guest: a persistent `vscode-server.img` volume** mounted at `/home/iosta/.vscode-server`. The guest home is
  ephemeral tmpfs, so without this every boot re-downloaded the server + remote extensions (tens of MB, ~a minute before
  the editor connects). Same mechanism/lifecycle/trust tier as the store-overlay volume: lives in the per-instance state
  dir, survives `sandvm stop`/relaunch, deleted by `sandvm rm`, only ever holds VS Code's own downloads (2G sparse cap).
  Fresh ext4 mounts root-owned; a root oneshot (`vscode-server-volume-perms`) chowns the mount root to iosta. A tmpfiles
  `z` rule was tried first and **does not work**: tmpfiles refuses to touch a root-owned path under a user-owned home
  ("Detected unsafe path transition /home/iosta → /home/iosta/.vscode-server", seen in a live guest's journal) — the
  refusal triggers on exactly the state the rule exists to fix. The symptom was VS Code dying with "Connecting with SSH
  timed out" (the bootstrap piped over ssh can't write into `~/.vscode-server`, produces no output VS Code recognises,
  and the extension just waits out its `remote.SSH.connectTimeout` — now set to 60s in `dev.vscode`, since a
  first-connect server download over SLIRP can also outlast the 15s default).
- **Host: `dev.vscode` changes.** The `ms-vscode-remote.remote-ssh` extension is now declared, and
  `remote.SSH.configFile` was re-pointed from `~/.ssh/sshconfig.local` to `~/.ssh/config`. The old value predated the
  HM-managed ssh config and was the silent killer: VS Code read _only_ that file, which contains no
  `Include ~/.ssh/config.d/*` line — so the `sandvm-*` Host blocks the wrapper writes resolved fine for the ssh CLI but
  were invisible to VS Code. `~/.ssh/config` Includes both `sshconfig.local` and `config.d/*`, so nothing was lost.
- **Host: `remote.SSH.useLocalServer: false` — required because the guest's login shell is fish.** In the default
  local-server mode, Remote-SSH opens a plain ssh session (no remote command) and pipes its install script into the
  **login shell**. That script is bash, and fish rejects it at _parse_ time (`fish: Unsupported use of '='`, exit 127)
  without executing a single line — VS Code never sees its start marker and reports only "Connecting with SSH timed out"
  (verified by piping the script's opening lines into a guest by hand). With `useLocalServer: false` the extension
  instead runs `ssh <host> sh` — an explicit remote command, so sshd invokes `fish -c sh` and the script runs under `sh`
  regardless of the login shell. Any future guest whose user shells out of bash/zsh needs this same setting; the
  alternative (bash as iosta's login shell, exec'ing fish when interactive) was rejected because the guest's agent.env
  exports, `SSH_AUTH_SOCK` glue and herdr autostart all live in fish's config. Paired with it, two more `dev.vscode`
  pieces:
  - `remote.SSH.remotePlatform = { "sandvm-*" = "linux" }` — without a matching entry the extension asks for the
    platform on the first connect to each new instance. The map keys support `*` wildcards (per the extension's own
    setting description), and the extension notes this setting will become _required_ when `useLocalServer` is off.
  - **settings.json is installed as a mutable file, not HM's usual read-only symlink** (a `home.activation` step copies
    the declared JSON on every switch). Reason: in `useLocalServer: false` mode the extension flags `storePlatform` on
    _every_ successful connect (`tryInstall` in extension.js, unconditional), and its save guard checks only for an
    **exact** hostname key — the wildcard satisfies resolution but never the guard — so after every connect it writes
    `remotePlatform["sandvm-<name>"] = "linux"` into `settings.json`. Against a read-only symlink that write fails and
    nags every time; against the mutable file it succeeds silently, and the next `nixos-rebuild switch` resets the file
    to the declared state (the accumulated exact entries are redundant with the wildcard anyway). Side benefit: ad-hoc
    UI settings tweaks stop erroring too — they now last until the next switch.

Terminals inside a VS Code remote window are plain fish, not herdr (the herdr autostart is gated on `SSH_TTY`, which VS
Code's exec-channel sessions don't set — deliberate, same as the qemu console). They get `/run/agent.env` exports like
any other fish session, and the forwarded ssh-agent via the stable `~/.ssh/agent.sock` symlink whenever some
agent-forwarding ssh session is (or has been) connected — VS Code's own connection uses `~/.ssh/config` now, so it
forwards the agent itself per the `Host sandvm-*` block.

Rollout gotchas: the host side (extension + setting) needs a `nixos-rebuild switch`; the guest side is rebuilt fresh on
every `sandvm` launch, so an **already-running** sandbox must be stopped and relaunched to pick it up. First connect per
instance still downloads the server once; the volume makes every later connect warm.

## Why imperative, not declarative/host-managed

microvm.nix supports two modes: (1) `microvm.host.enable` + `microvm.vms.*` — host registers VMs as systemd services,
meant for always-on, host-known VMs; (2) build a guest's `config.microvm.declaredRunner` directly and exec it
(`nix run .#name`) — the documented "imperative" pattern (see `microvm.nix`'s own `flake-template/flake.nix`). `sandvm`
needs mode 2: the project path is only known at invocation time, for an arbitrary folder, not a fixed list of host-known
VMs. This is also why no `microvm.nixosModules.host` import exists anywhere in this repo — it's simply not needed for
mode 2.

## Networking

Usermode (SLIRP) networking (`microvm.interfaces = [{ type = "user"; ... }]`) — no host tap/bridge setup, and
reachability is host-only by design (matches "connections from the local machine", not the LAN). SSH is one
`microvm.forwardPorts` entry (host port assigned by the wrapper, persisted per-instance in
`~/.local/state/sandvm/<name>/ssh_port`); `--port N` adds more, mapped 1:1.

Inside the guest, eth0 gets DHCP from **systemd-networkd** (`networking.useNetworkd`, in `microvm-guest.nix`) — not
NetworkManager. `roles.default` used to ship NetworkManager + avahi to every consumer; they moved to `roles.workstation`
on 2026-07-14 (a desktop network daemon was the single biggest guest boot-time/RAM cost, and mDNS behind SLIRP reaches
nothing). `wait-online.anyInterface` lets `network-online.target` — the gate for `sandvm-workspace-init` — fire as soon
as that one link is up. (Den's `primary-user` battery still puts iosta in a `networkmanager` group that no longer exists
in the guest; NixOS silently drops unknown groups, harmless.)

## Memory: a 32G ceiling, not a reservation

`--mem` defaults to 32768 (MiB). That is deliberately generous because it's a **cap**: qemu only allocates guest pages
as they're touched, and the guest runs a virtio-balloon that microvm.nix configures with `free-page-reporting=on`
(`microvm.balloon = true` in `microvm-guest.nix`) — memory the guest frees (e.g. page cache dropped after a big
`nix build`) is returned to the host automatically, no QMP babysitting, `deflate-on-oom` on. The one fixed cost that
does scale with the ceiling is the guest kernel's `struct page` array, ~1.5% of `mem` (~500M at 32G) — lower `--mem` for
many concurrent idle sandboxes.

## LLM access for the agent harness

Two lanes, both wired in `microvm-guest.nix`:

**Local (llama-server, zero config):** qemu's usermode gateway (`10.0.2.2` from the guest) forwards to the host's
loopback interface, so abhaile's llama-server on `127.0.0.1:8080` (`modules/den/aspects/services/llm.nix`) is reachable
from inside every sandvm guest at `http://10.0.2.2:8080/v1` with **no change** to llm.nix's bind address. The guest
seeds `~/.omp/agent/models.yml` at boot (tmpfiles `C` — copy-if-absent into iosta's ephemeral home, so omp can rewrite
it and a fresh boot resets it) declaring this as omp's `local` provider — keep the model ids/context sizes in sync with
llm.nix's router presets. Inside a guest: `omp --model local/qwen3.6-35b-a3b` (or `/model` in-session). Verified
end-to-end 2026-07-13 (omp print-mode round trip through the sandbox to the GPU and back).

Only qwen is declared, deliberately: **omp's own harness overhead (system prompt + tool definitions) measured ~17.1k
tokens** (omp's `~/.omp/logs`: "Pre-prompt context maintenance … contextTokens: 17120"), which overflows llama-3.1-8b's
16k server-side `ctx-size` — every request 400s before generation starts. llama-server still serves the 8B fine to
smaller-context clients (curl, scripts); making it omp-usable means raising its `ctx-size` in llm.nix, which is a
VRAM/benchmarking decision for that aspect, not this one.

**Cloud, two ways.** Both land in the guest the same way: `sandvm` merges them into one temp file per launch
(`~/.local/state/sandvm/<name>/agent.env`, 0600), passes the _path_ to the guest build, and `microvm.credentialFiles`
turns it into a qemu `fw_cfg` systemd credential whose contents are read at VM start — **key material never enters the
world-readable `/nix/store`** on either side (the whole design constraint; a Nix path _literal_ instead of a string
would silently defeat it by copying the file to the store at eval time). In the guest, a oneshot installs the merged
file at `/run/agent.env` (iosta, 0600, tmpfs — gone on stop) and fish exports its lines into every session. No lines at
all → no credential → local provider only.

- **Plain API keys**: put `KEY=value` lines (e.g. `OPENAI_API_KEY=…`) in `~/.config/sandvm/agent.env` on the host (0600;
  create it yourself — nothing manages it). Billed per-token against that provider's API.
- **Anthropic via your Pro/Max subscription, not API billing**: `dev.tools.omp-auth-broker` runs `omp auth-broker serve`
  as a persistent `systemd --user` service on the host — a credential store + HTTP endpoint (`127.0.0.1:8765`) that
  other omp instances can pull fresh credentials from instead of storing their own copy. One-time setup, on the host:
  `omp auth-broker login anthropic` **then `systemctl --user restart omp-auth-broker`** — the restart isn't optional.
  `login` writes straight to `~/.omp/agent/agent.db`; the already-running server loaded its credential list into memory
  once at startup and has no file-watcher, so it's blind to the new row until it re-reads the db on its own boot
  (confirmed 2026-07-13 — a fresh login was invisible to a live broker, and to sandboxes already running against it,
  until the restart; no guest relaunch was needed afterwards, since guests query the broker fresh per-request). `sandvm`
  auto-detects the resulting `~/.omp/auth-broker.token` and adds `OMP_AUTH_BROKER_URL=http://10.0.2.2:8765` +
  `OMP_AUTH_BROKER_TOKEN=<token>` to every launch's merged agent.env — the guest never stores the Anthropic OAuth token
  itself, it asks the broker each time, so **the broker's own background refresher (60s cadence, refreshes anything
  expiring within 5min) is what keeps a sandbox's session alive**, not anything guest-side. This is exactly the fix for
  "the sandbox that could refresh the token is gone by the time it expires." Model ids need no guest-side declaration
  (unlike the custom `local` llama-server provider) — Anthropic is a first-class omp provider; once the broker resolves
  a credential, `--model anthropic/<id>` just works.
- The broker's bearer token is a skeleton key to **every** credential it holds, to anything on the loopback path — which
  in practice means any sandvm guest you launch. A rogue agent can't escape the filesystem sandbox through this, but it
  _can_ spend down your Pro subscription's rate limits/quota. Same trust tier as the local-llama-server reachability
  above, just: mind what you `--auto-approve` in a sandbox with a real subscription behind it.

## Known quirks

- (Historical, fixed 2026-07-13: when the guest ran df's full HM identity via `roles.dev`, it also inherited the
  `sandvm` binary itself and a spare `omp auth-broker serve` per boot. The iosta/`roles.dev-sandbox` guest identity
  includes neither.)
- `nix run`/`nix build .#sandvm-guest` needs `--impure` and `MICROVM_WORKDIR` set in the environment first (the `sandvm`
  wrapper always does both; don't invoke the flake output directly except for debugging). Without it, the guest module
  falls back to sharing `/var/empty` as `/workspace` and prints a `lib.warn` rather than hard-failing — a hard assertion
  here would break `nix flake check` for everyone, always, since flake check evaluates
  `nixosConfigurations.*.config.system.build.toplevel` purely (no `--impure`).
- A crashed/interrupted launch can orphan the `virtiofsd` process for that instance — systemd's cgroup teardown doesn't
  reliably reap a backgrounded child when the unit's main process (qemu) exits/errors on its own rather than being
  stopped via `sandvm stop`. The orphan holds `virtiofsd`'s pid-file lock, so every subsequent relaunch fails
  immediately with "Resource temporarily unavailable" until it's cleared. `sandvm` now defensively `pkill`s any matching
  stale `virtiofsd` and removes its lock file before each launch.
- The transient unit is launched with `systemd-run --collect`, so a nonzero exit (a crash) auto-unloads it instead of
  sitting "failed" — without that, relaunching the same `<name>` would hit "Unit … was already loaded or has a fragment
  file" until a manual `systemctl --user reset-failed`.
- `sandvm` is home-manager-installed, so changes to `pkgs/by-name/sandvm/package.nix` don't reach `$PATH` until the next
  `nixos-rebuild switch`/`test` — a plain `git commit`/`nix build` isn't enough. Easy to forget and then debug a "fix"
  that was never actually deployed.
- The console (`sandvm`'s own foreground output — `ssh`'s fallback if SSH itself is broken) logs in as `iosta` /
  password `iosta`. Autologin was tried first and rejected (silently dropping into a shell on every launch); a throwaway
  typeable password — same pattern as `virtualisation/vm-login.nix`'s debug VM — was the alternative. The console
  deliberately does _not_ auto-start herdr (the autostart is gated on `SSH_TTY`), so it stays usable for debugging.
- `sandvm list`'s NAME column shows the `sandvm-<name>` form — that's the literal SSH `Host` alias (`ssh sandvm-<name>`
  works; the bare name without the prefix does not, since no `Host` entry matches it).

## Not built yet (tracked in TODO.md)

- LAN-wide (non-loopback) exposure of guest-hosted services (would need tap+bridge networking instead of usermode).
- Network egress allowlisting inside the guest (smolvm has a good pattern for this: default-deny + an explicit
  allowed-hosts list).
