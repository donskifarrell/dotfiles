# `sandvm` — per-folder sandboxed microVMs for coding agents

## What this is

`sandvm <path>` boots a throwaway NixOS microVM (microvm.nix, qemu) whose _only_ writable channel back to the host
filesystem is `<path>`, mounted at `/workspace`. It exists so a coding-agent harness (Pi/oh-my-pi — not yet wired in,
see "Not built yet" below) can run against a real project with a real dev toolchain (devenv.sh, direnv, git, df's shell
config) without being able to write — or even see — anything outside that one folder, even if the agent or the LLM
behind it goes rogue.

## Usage

```
sandvm [--port N ...] [--cpu N] [--mem N] [<path>]   # default <path>: $PWD
sandvm stop [<name>]                                  # default: current dir's
sandvm list
```

`sandvm` blocks in the foreground (it's a `systemd-run --user --scope` running `virtiofsd-run` and `microvm-run` from
the `nix build --impure .#sandvm-guest` result); Ctrl-C or `sandvm stop` from another terminal ends the session. It
prints, on start:

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
like a real host: `roles.default`, `roles.dev`, and (via the standard `users.df = { }` mechanism) df's full home-manager
identity — fish, git identity, lazygit, aliases, even desktop/workstation HM packages that just sit unused in a headless
guest. That's an accepted tradeoff for the guest shell feeling like a slice of abhaile rather than a bare container; a
leaner guest identity is a possible future optimization if build/eval time becomes annoying (see "Known quirks" below).

Files:

- `modules/den/aspects/virtualisation/microvm-host.nix` — host-side: just a persistent SSH host key at
  `/var/lib/sandvm/hostkey`, generated once via `system.activationScripts` (not left to the guest to generate per-boot,
  which would both churn `known_hosts` and race between concurrent instances' first boot).
- `modules/den/aspects/virtualisation/microvm-guest.nix` — guest-side: `microvm.shares`/`forwardPorts`/`interfaces`,
  sshd pointed at the shared host key, df's authorized key (public — see "What's deliberately not shared" below).
- `modules/den/hosts/sandvm.nix` — the Den host declaration + the `packages.sandvm-guest` flake output
  (`nixosConfigurations.sandvm.config. microvm.declaredRunner`).
- `pkgs/by-name/sandvm/package.nix` — the CLI wrapper (name/port bookkeeping, `~/.ssh/config.d/sandvm`,
  `systemd-run --user --scope` lifecycle).
- `modules/den/aspects/dev/tools/sandvm.nix` — installs the CLI onto df's `$PATH`, included via `roles.dev`.

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
df, not root) and can't otherwise vouch for arbitrary ownership over 9p. Result: df (uid 1000 in the guest, matching the
host) couldn't write into its own project's share at all. virtiofsd passes through real host uid/gid directly instead of
trying to remap anything, which works here specifically because the guest's df already has the same uid as the host's
df.

The cost: virtiofs needs a separate `virtiofsd` process started as a prerequisite (`bin/virtiofsd-run`, bundled
alongside `bin/microvm-run` in the same `sandvm-guest` build once any share uses `proto = "virtiofs"`), and that
companion-process lifecycle normally only gets managed automatically under microvm.nix's systemd-managed
`microvm.host`/`microvm.vms.*` path, which `sandvm` deliberately doesn't use (see below) — so the `sandvm` wrapper
starts `virtiofsd-run` itself (backgrounded inside the same `systemd-run --user --scope`, so `sandvm stop` tears down
both together via the cgroup) and polls for its socket before handing off to `microvm-run`, since there's no
`Type=notify` readiness wiring to lean on outside the host-managed path.

### What's deliberately NOT shared into the guest

`secrets.home` (df's real SSH/git private keys) is **not** included in the guest's aspect list, and only df's _public_
key goes in (for inbound SSH — same literal as `modules/den/users/df.nix`, safe to duplicate). Outbound git push/pull
auth from inside a sandbox is out of scope for now — the concern isn't just "the agent shouldn't write outside
`/workspace`" but that it shouldn't be able to _read and exfiltrate_ real credentials either, since it already has
network access to talk to an LLM. See "Not built yet" below for the planned fix (SSH-agent forwarding, so key material
never touches the guest disk at all).

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

**Local/cloud LLM reachability (informational — not wired in yet):** qemu's usermode gateway (`10.0.2.2` from the guest)
forwards to the host's loopback interface, so abhaile's llama-server on `127.0.0.1:8080`
(`modules/den/aspects/services/llm.nix`) is _already_ reachable from inside a sandvm guest at `http://10.0.2.2:8080/v1`
with **no change** needed to llm.nix's bind address. Worth remembering before "fixing" this the hard way later.

## Known quirks

- `roles.dev` (which every sandvm guest's df user pulls in for HM) now includes `dev.tools.sandvm` itself — so a
  sandbox's home-manager profile contains the `sandvm` binary too. Running it _inside_ a sandbox will fail cleanly
  (`/home/df/.dotfiles` isn't shared into the guest, only `/workspace` is) rather than nesting sandboxes. Harmless, just
  a by-product of giving the guest df's full HM identity.
- `nix run`/`nix build .#sandvm-guest` needs `--impure` and `MICROVM_WORKDIR` set in the environment first (the `sandvm`
  wrapper always does both; don't invoke the flake output directly except for debugging). Without it, the guest module
  falls back to sharing `/var/empty` as `/workspace` and prints a `lib.warn` rather than hard-failing — a hard assertion
  here would break `nix flake check` for everyone, always, since flake check evaluates
  `nixosConfigurations.*.config.system.build.toplevel` purely (no `--impure`).
- A crashed/interrupted launch can orphan the `virtiofsd` process for that instance — systemd's `--scope` cgroup
  teardown doesn't reliably reap a backgrounded child when the scope's main process (qemu) exits/errors on its own
  rather than being stopped via `sandvm stop`. The orphan holds `virtiofsd`'s pid-file lock, so every subsequent
  relaunch fails immediately with "Resource temporarily unavailable" until it's cleared. `sandvm` now defensively
  `pkill`s any matching stale `virtiofsd` and removes its lock file before each launch.
- `sandvm` is home-manager-installed, so changes to `pkgs/by-name/sandvm/package.nix` don't reach `$PATH` until the next
  `nixos-rebuild switch`/`test` — a plain `git commit`/`nix build` isn't enough. Easy to forget and then debug a "fix"
  that was never actually deployed.
- The console (`ssh`'s only fallback if SSH itself is broken) autologs in as `df` — no username/password to type,
  because none is set (df/root have no password hash in the guest at all; SSH pubkey is the only intended path in). If
  SSH is unreachable, just watch the `sandvm` command's own foreground output (it _is_ the console).
- `sandvm list`'s NAME column shows the `sandvm-<name>` form — that's the literal SSH `Host` alias (`ssh sandvm-<name>`
  works; the bare name without the prefix does not, since no `Host` entry matches it).

## Not built yet (tracked in TODO.md)

- Packaging/installing Pi or oh-my-pi inside the guest.
- Wiring a cloud API key or the local llama-server into the guest.
- SSH-agent forwarding for git push/pull auth (so private key material never touches the guest disk, addressing the
  exfiltration concern above).
- LAN-wide (non-loopback) exposure of guest-hosted services (would need tap+bridge networking instead of usermode).
- Network egress allowlisting inside the guest (smolvm has a good pattern for this: default-deny + an explicit
  allowed-hosts list).
