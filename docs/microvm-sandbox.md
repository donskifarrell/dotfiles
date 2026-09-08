# `scoite` — sandboxed microVMs for coding agents

## What this is

`scoite` boots throwaway NixOS microVMs (microvm.nix, qemu) for coding agents to work in. A sandbox's _only_ writable
channel back to the host filesystem is one folder, mounted at `/workspace`. It exists so an agent harness (claude-code,
`pi`, whatever comes next) can run against a real project with a real toolchain without being able to write — or even
see — anything outside that one folder, even if the agent or the LLM behind it goes rogue.

Sandboxes come in two **types**, so the closure you pay for matches the work:

| `--type`  | what it is                                                                                                                 | closure |
| --------- | -------------------------------------------------------------------------------------------------------------------------- | ------- |
| `minimal` | shell, git, agent harness, internet. No dev toolchain at all.                                                              | ~3.7 G  |
| `dev`     | + python, node, headless chromium, compilers/nix-ld, the full TUI shell + git stack, devenv/direnv and herdr. The default. | ~10.7 G |

Each type is one Den host (`modules/den/hosts/scoite.nix`) built from one role tier (`modules/den/roles/sandbox.nix`);
`dev` includes `minimal`. (Until 2026-08-24 there were four tiers — `minimal`/`generic`/`devenv`/`workstation`; the
middle two were never chosen deliberately, so they collapsed into `dev`. An existing sandbox of a retired type is
migrated to `dev` on its next start.)

## Usage

The command is `scoite`, with `sc` as a short alias (a real binary, so it works from scripts and over ssh too).

```
scoite new [opts] [<name>]      create a sandbox (and start it)
scoite start [opts] [<name>]    start an existing sandbox
scoite stop [<name>]            stop it (state is kept)
scoite rm [<name>...]           stop + delete it, storage and all (irreversible)
scoite rename [<name>] <new>    rename it, without a restart
scoite ssh [<name>] [-- cmd]    ssh in, starting it first if stopped
scoite bind [<name>] [<host> [<guest>]]   share a host folder into the guest, live both ways (or list binds)
scoite unbind [<name>] <path>   stop sharing one
scoite creds [<name>|--all]     re-push host credentials/config into a running sandbox (no restart)
scoite list                     list every sandbox: type, state, DNS name, bridge IP, forward address, disk, workspace
scoite resize [<name>] [opts]   grow a sandbox's disks
scoite expose [<name>] <port>   forward a port into a running sandbox (no restart)
scoite expose --lan <port>      also reach that port from the LAN (opt-in, per port)
scoite unexpose [<name>] [--lan] <port>   stop forwarding one
scoite <path>                   shorthand: new-or-start for a folder
```

new/start options: `--name <name>` (new only), `--type minimal|dev` (new only), `--workspace <path>` (new only),
`--cpu N`, `--mem MiB`, `--disk MiB`, `--home-disk MiB`, `--port N` (repeatable; only for ports outside the default
forwarded set), `--bind <host>[:<guest>]` (repeatable, max 4 — see
[Binding extra host folders](#binding-extra-host-folders-scoite-bind)), `--ssh`/`-s`, `-f`/`--foreground`, `--fresh`.

```console
$ sc new --type minimal --ssh scratch          # named, no host folder, drops you into a shell
$ cd ~/dev/myproject && sc new                 # proposes scoite-myproject, lets you edit it; type dev
$ sc ssh myproject -- claude -p 'run the tests'
$ sc list
NAME                     TYPE     STATUS   DNS                        IP            FORWARD       LAN       BINDS  ON-DISK WORKSPACE
scoite-myproject         dev      running  scoite-myproject.local     10.77.0.106   127.44.19.1   -         1      2.1G    /home/df/dev/myproject
scoite-scratch           minimal  stopped  -                          -             127.212.6.1   -         -      136M    …/scoite-scratch/workspace
```

A guest web server is viewable from the host at that address on the **same port it uses inside the guest** — a Vite dev
server on `:5173` is `http://127.44.19.1:5173`, with no flag and no restart (see [Networking](#networking) for the
forwarded-by-default set, and `scoite expose` for anything outside it).

A sandbox does **not** need a host folder. Without `--workspace` it gets a private one inside its own state dir, so
`/workspace` always exists and is always writable — and is still visible from the host for handing files in and out.

**Names.** A sandbox is `scoite-<name>`, and that one string is its state directory, its SSH alias, its systemd unit,
its hostname inside the VM and its mDNS name. `scoite new` in a folder proposes `scoite-<folder>` and lets you edit it
(`--name` skips the prompt; a non-interactive caller takes the default). Two different folders with the same basename
collide, and the CLI refuses rather than choosing for you — pass `--name`. Commands accept either spelling, `mono` or
`scoite-mono`. `scoite rename` changes the name of a **running** sandbox, ssh alias and `.local` name included, without
interrupting anything inside it; the systemd unit keeps its original name (a running unit cannot be renamed) and
`scoite list` keeps working regardless.

Sandboxes run detached by default (a `systemd-run --user --unit` transient service running `virtiofsd` and the guest
runner); `journalctl --user -u scoite-<name> -f` follows the console (`<name>` here is the unit name, fixed at creation
— see `ID` in the instance's config), `-f`/`--foreground` blocks in the invoking terminal instead. Every shell in the
guest lands in `/workspace`. Fish completions for subcommands, flags, types and known instance names ship in the package
itself.

## Architecture

Two Den hosts — `scoite-minimal` and `scoite-dev` (`modules/den/hosts/scoite.nix`) — share one guest base
(`roles.default` + `virtualization.microvm-guest`) and differ only by which `roles.sandbox.*` tier they carry. Each
emits a flake package `scoite-guest-<type>` (the tier's `config.microvm.declaredRunner`), which is what the CLI builds
and execs.

The guest user is **`iosta`** (`modules/den/users/iosta.nix`) — a sandbox-only account, uid-pinned to 1000 to match the
host-side project owner for the virtiofs `/workspace` share, with none of df's identity and no key material of its own.
The tier role is attached both to the host (for its `nixos` keys) and to `users.iosta` (for its `homeManager` keys),
because Den resolves an entity's `aspect` for its own class only. Note that Den entities take a single `aspect` _value_
— a free-form `includes` on `den.hosts.<sys>.<name>` is silently ignored, which is why the tiers are composed inline in
the host file.

### Nothing per-instance is baked into the system closure

Everything the CLI varies per launch — workspace path, ssh/forwarded ports, cpu, mem, disk sizes, credential paths —
touches only options that end up on **qemu's command line**, never `system.build.toplevel`. That is verifiable:

```console
$ MICROVM_WORKDIR=/a MICROVM_CPU=2  nix eval --impure --raw .#nixosConfigurations.scoite-dev.config.system.build.toplevel.drvPath
/nix/store/s6dbj4ng…-nixos-system-sandbox-26.11.…drv
$ MICROVM_WORKDIR=/b MICROVM_CPU=8  nix eval --impure --raw .#nixosConfigurations.scoite-dev.config.system.build.toplevel.drvPath
/nix/store/s6dbj4ng…-nixos-system-sandbox-26.11.…drv   # identical
```

So every sandbox of a type shares one already-built guest system; a relaunch can at most rebuild the ~2 kB runner
script. The one thing that had to move to make this true was the hostname: it is now the static string `sandbox` in the
closure, and the real instance name arrives at boot as a systemd credential (`scoite-hostname.service`). Previously
`networking.hostName` was the per-launch instance name, which put that name into `/etc` and so gave every single sandbox
its own NixOS generation.

The per-launch env-var contract (read with `builtins.getEnv` in `virtualization.microvm-guest`, hence
`nix build --impure`) is: `MICROVM_WORKDIR`, `MICROVM_SSH_PORT`, `MICROVM_HOST_ADDR`, `MICROVM_PORTS`, `MICROVM_CPU`,
`MICROVM_MEM`, `MICROVM_DISK`, `MICROVM_HOME_DISK`, and the credential paths `MICROVM_AGENT_ENV`, `MICROVM_GITCONFIG`,
`MICROVM_CLAUDE_CREDS`, `MICROVM_SSH_CONF`, `MICROVM_INSTANCE_FILE`.

### Per-instance state

`~/.local/state/scoite/<name>/`:

| file                    | what                                                                           |
| ----------------------- | ------------------------------------------------------------------------------ |
| `config`                | `KEY=value` — type, workspace, cpu, mem, disk sizes, extra ports, ssh port,    |
|                         | loopback address. Sourced by every later command; this is what makes           |
|                         | `scoite start <name>` possible at all. An instance created before per-instance |
|                         | addresses has no `ADDR` and is migrated (and told so) on its next start.       |
| `runner` / `runner.key` | `nix build --out-link` result (also a GC root) + its cache fingerprint.        |
| `nix-store-overlay.img` | overlayfs upper for `/nix/.rw-store`. Persistent, sparse.                      |
| `home.img`              | `/home/iosta`. Persistent, sparse.                                             |
| `agent.env`, `instance` | per-launch credential files handed to qemu over fw_cfg.                        |
| `ssh-conf.tar`          | ditto: the GitHub ssh aliases + the _public_ halves of their keys, restaged    |
|                         | from `~/.ssh/sshconfig.local` on every launch (`ssh-conf.d/` is its staging).  |
| `workspace/`            | only when created without `--workspace`.                                       |
| `sandbox*.sock`         | qemu's QMP socket and virtiofsd's socket.                                      |

The guest's `/` stays ephemeral tmpfs, discarded on stop. `scoite rm` deletes the whole directory — which also drops the
GC root, so the guest closure becomes collectable again.

Instances that predate 2026-09-08 also hold an `omp-conf.d/` staged by the removed omp-config share, and a `~/.omp` in
their `home.img`. Both are inert — delete them by hand if you want the space back.

Files:

- `modules/den/aspects/virtualisation/microvm-host.nix` — host-side: the persistent SSH host key at
  `/var/lib/scoite/hostkey` (generated once via `system.activationScripts`, so `known_hosts`/VS Code never see a changed
  identity and concurrent first boots can't race), plus the harmonia binary cache (see "Sharing with the host").
- `modules/den/aspects/virtualisation/microvm-guest.nix` — guest-side: shares/volumes/ports/credentials, sshd pointed at
  the shared host key, the boot-time credential installers, the grow-fs unit + timer, the workspace pre-installer, the
  console fallback password, the LLM wiring.
- `modules/den/roles/sandbox.nix` — the two tiers.
- `modules/den/users/iosta.nix` — the guest user; tier-independent.
- `modules/den/hosts/scoite.nix` — the two Den hosts + the `scoite-guest-<type>` flake outputs.
- `pkgs/by-name/scoite/package.nix` — the CLI (instance bookkeeping, per-instance loopback address, forwarded-port
  selection, `~/.ssh/config.d/scoite`, runner cache, `systemd-run --user --unit` lifecycle, QMP resize and
  `hostfwd_add`/`hostfwd_remove`) plus `completions.fish`, merged into the same output via `symlinkJoin`
  (`writeShellApplication`'s `buildCommand` can't take a `postInstall` — it bypasses `genericBuild`'s phases entirely).
- `modules/den/aspects/dev/tools/scoite.nix` — installs the CLI onto df's `$PATH` (via `roles.dev`) and sets
  `ForwardAgent` for `scoite-*`.
- `modules/den/aspects/dev/tools/headless-browser.nix` — headless Chromium + playwright/puppeteer wiring, in the `dev`
  tier (see "UI validation").
- `modules/den/aspects/shell/xdg-open.nix` — a headless `xdg-open` that reports the URL instead of opening it, in both
  tiers (see "`xdg-open` for a machine with nothing to open with").
- `modules/den/aspects/dev/vscode.nix` — not scoite-specific but load-bearing: Remote-SSH extension +
  `remote.SSH.configFile` pointing at `~/.ssh/config`.
- `modules/den/aspects/dev/tools/herdr.nix` — herdr (herdr.dev, from `nix-ai-tools`), the terminal multiplexer for agent
  sessions. In `roles.dev` on abhaile and in the `dev` tier (with `dev.tools.herdr.autostart`, which `exec`s an
  interactive `ssh scoite-<name>` straight into it). Dropped 2026-08-26, back 2026-09-08 when df moved to pi + herdr.

Named `scoite`, not `devbox`: nixpkgs already has an unrelated package literally called `devbox` (Jetify's tool). Using
that name for `pkgs.devbox` in home-manager would have silently resolved to the wrong package — there's no overlay
merging this flake's own `pkgs/by-name` into the nixpkgs instance NixOS/HM modules see, so this flake's own packages
must be referenced via `inputs.self.packages.${system}.<name>`, not `pkgs.<name>`.

## Sharing with the host: not rebuilding what abhaile already has

Four separate mechanisms, because "don't rebuild" has four separate failure modes:

1. **The host's `/nix/store` is mounted read-only** at `/nix/.ro-store` and overlaid, so every store path abhaile has is
   already _present_ in the guest at zero copy cost. This is the standard microvm.nix pattern and predates the rework.
2. **The host serves its store as a binary cache** — `services.harmonia.cache` on `127.0.0.1:5000`
   (`virtualisation/microvm-host.nix`), which SLIRP exposes to guests at `http://10.0.2.2:5000`; the guest lists it
   ahead of `cache.nixos.org` in `nix.settings.substituters` **and it is served with `priority = 10`** — nix chooses
   substituters by priority, not list order, and harmonia's default 50 loses to cache.nixos.org's 40, so until
   2026-08-25 guests downloaded from the internet what abhaile already had on disk. Mechanism 1 makes host paths
   readable but doesn't register them in the guest's Nix _database_, so a guest build of something abhaile already has
   would otherwise refetch it from the internet or rebuild it. It runs **unsigned** (no signing key on either side,
   `require-sigs = false` in the guest): the guest can already read that exact store through mechanism 1, so serving it
   grants nothing new, and there is no key to manage just to talk to ourselves. The guest also sets
   `connect-timeout = 3` + `fallback = true` so a stopped host cache can never stall a guest build.
3. **The runner build is cached per instance.** Launches used to pay a full impure NixOS eval every time (tens of
   seconds). Now the guest system closure is instance-independent (above), so the only thing a relaunch can rebuild is
   the runner script — and `scoite` skips even that when nothing moved, keying `runner.key` on the flake's contents
   (HEAD + unstaged diff + untracked files) and every value that reaches the qemu command line. Measured on a warm
   store: **~11 s when something changed, ~2.6 s when nothing did.** `--fresh` forces a rebuild.
4. **The guest's Nix database is seeded from `regInfo` at boot** (`systemd.services.register-nix-paths` in
   `microvm-guest.nix`). Mechanism 1 makes the host's paths _readable_, but leaves them **invalid** in the guest's own
   SQLite db — so the first thing that asks Nix to realise the system closure re-substitutes ~2700 paths it can already
   read. See "Why a half-finished substitution breaks the guest" below for why that is destructive rather than merely
   slow. qemu's cmdline already carried `regInfo=` (microvm.nix sets it, and its closure-info does include the
   home-manager generation); the consumer was missing, because it lives in nixpkgs'
   `nixos/modules/virtualisation/qemu-vm.nix`, which microvm.nix does not import. Added 2026-09-08.

### Why a half-finished substitution breaks the guest

Worth understanding before touching any of the above, because the failure does not look like a Nix problem.

To substitute a path, Nix **deletes** the existing one and re-extracts it. Deleting a lower-layer path through an
overlay leaves an _opaque_ upper directory that hides the intact original completely — so while the copy is in flight,
the merged `/nix/store` shows a partial path instead of the host's good one. Interrupt it and that state is permanent.

The interrupt that actually happened (2026-09-08, scoite-bbm, after a `nix flake update` moved the whole closure): the
home-manager NixOS module hardcodes `TimeoutStartSec=5m`, activation needed longer than that to re-substitute the
profile, and systemd SIGTERMed it at exactly 5m00s. The result was 212 truncated store paths shadowing working ones — no
`coreutils` on `PATH` (fish erroring on `dirname`/`mkdir`/`uname`), `ETXTBSY` on `exec` of anything mid-write,
`systemctl` unable to load `libsystemd-shared-261.so`, and a `nix-store` too damaged to repair anything (SIGBUS, from
demand-paging past EOF of its own truncated libraries). A guest in that state cannot fix itself; the store overlay has
to be discarded (`scoite stop`, delete `nix-store-overlay.img`, `scoite start` — the runner re-creates and `mkfs.ext4`s
a missing volume) or the instance recreated.

Both halves are now closed: mechanism 4 means activation has nothing to substitute in the first place, and
`TimeoutStartSec` is forced to `infinity` for `home-manager-iosta` so that whatever a genuinely cold boot does still
have to fetch cannot be killed part-way. Keep both — the timeout override alone would have turned this into a slow boot,
and mechanism 4 alone still leaves any other long-running activation able to reproduce it.

## Disks: sparse ceilings that grow

Both volumes are sparse raw images: the declared size is a ceiling, and the host only pays for blocks the guest actually
writes. A fresh 4 GiB store overlay + 2 GiB home occupy ~134 MiB between them. Defaults are per type: `dev` gets
`--disk 32768` (the nix store overlay) and `--home-disk 16384` (`/home/iosta`), `minimal` 8192 and 4096, all MiB.

`scoite resize <name> --disk N --home-disk N` grows them, running or not. It truncates the backing file, and for a
running guest also issues a QMP `block_resize` on qemu's socket so the virtio-blk device grows live. The guest's
`scoite-grow-fs` unit then stretches the filesystem onto the new space: it runs at boot (picking up a resize done while
stopped) and on a 2-minute timer (picking up a live one), so no host→guest signalling channel is needed. Online
`resize2fs` on a filesystem that already fills its device is a fast no-op, which is what makes running it that often
free. Disks only ever grow — `resize` refuses to shrink.

## The security boundary

microVMs only ever see the host filesystem through explicit `microvm.shares`. The guest gets three, plus four opt-in
bind slots that are empty and read-only until you fill them:

- `/workspace` ← the project folder, **read-write**. Unless `scoite bind` is used, the only writable channel back to the
  host's _actual_ files.
- `/nix/.ro-store` ← host's `/nix/store`, **read-only** (standard microvm.nix pattern; shrinks the guest closure/boot
  time — read-only content-addressed store paths aren't an escape vector).
- `/etc/scoite-hostkey` ← the persistent SSH host key directory, read-write but containing nothing except that key.

Nothing else is shared from the real host filesystem. The guest also gets two writable _volumes_ (not shares —
auto-created disk image files) that live in the per-instance state dir rather than anywhere on the real host filesystem,
so they don't weaken this boundary:

- `nix-store-overlay.img` → `/nix/.rw-store`, the overlayfs upper layer (see "Why a writable store overlay" below). It
  only ever holds new, content-addressed Nix store paths the guest builds or fetches for itself — the same trust level
  as the read-only store share.
- `home.img` → `/home/iosta`, **persistent since 2026-08-22**. This is what makes the `dev` tier's premise real:
  `nix profile install`, `npm i -g`, `pip install --user`, shell history, `~/.vscode-server`, the agent's own state all
  survive stop→start, and `scoite rm` is what throws them away. Before this the home was tmpfs and only
  `~/.vscode-server` had a volume of its own, so an agent re-installed and re-logged-in on every boot.

The guest's actual root filesystem (`/`) stays ephemeral tmpfs, discarded on stop. Even a fully compromised agent inside
the guest cannot touch host files outside `/workspace` and whatever `scoite bind` was pointed at, see df's `$HOME`,
other projects, or secrets.

### Binding extra host folders (`scoite bind`)

`scoite bind ~/.pi` makes `~/.pi` on abhaile and `/home/iosta/.pi` in the guest **the same directory** — a file written
on either side is there on the other, immediately, with no sync layer. It is the same virtiofs passthrough `/workspace`
uses, so ownership maps straight through (guest `iosta` is uid 1000, same as df) and it is genuinely read-write.

```console
$ sc bind ~/.pi                       # -> /home/iosta/.pi  (default: ~/<basename>)
$ sc bind ~/notes '~/n' --ro          # explicit guest path (quote the ~), read-only
$ sc bind                             # what is bound here
$ sc unbind ~/.pi                     # either side's path identifies the entry
$ sc new --bind ~/.pi myproj          # bound from its first boot
```

**Binds are applied at boot**: adding or removing one on a running sandbox takes effect on its next `stop`/`start` (qemu
cannot grow a vhost-user device on the fly). `--ro` is enforced host-side by `virtiofsd --readonly`, so the guest's
mount options still read `rw` while writes fail with `EROFS`.

**This is the one deliberate hole in the boundary above.** Whatever is bound is writable by an agent inside the guest,
with none of the containment `/workspace` gets from being the only channel. The CLI refuses host paths that hold host
credentials or system state (`~/.ssh`, `~/.gnupg`, `~/.claude`, `~/.config/sops`, `~/.config/scoite`, the scoite state
root, `$HOME` itself, `/`, `/nix`, `/etc`, `/run`, …) unless `--force` says otherwise, and refuses guest destinations
owned by the guest system (`/nix`, `/etc`, `/run`, `/workspace`, `/mnt/host`, `/home/iosta` itself) with no override. It
also refuses a host path that contains or sits inside this sandbox's own workspace: two virtiofsd over one tree both
cache metadata (`cache=auto`) and would serve each other stale results.

**How it keeps one closure per tier.** A share's `mountPoint` lands in `system.build.toplevel`; its `source` does not
(`nixos-modules/microvm/mounts.nix` renders only tag/proto/mountPoint into `fileSystems`). So the guest declares a
**fixed** four slots at fixed mount points — `/mnt/host/0…3` — and the two per-instance halves travel the way
per-instance data always travels here:

- the **host** paths never reach the guest eval at all; they are `virtiofsd --shared-dir`, set by the CLI's `boot`,
- the **guest** destinations arrive as the `BINDS` systemd credential (`<slot> <path>` lines), and
  `scoite-binds.service` bind-mounts each `/mnt/host/<slot>` into place before home-manager activation and the first
  login. A bind mount, not a symlink, so the destination is a real directory to anything that inspects it.

Every slot needs a `virtiofsd` whether or not it is used — qemu aborts the launch when a declared vhost-user socket is
missing — so unused slots get an empty placeholder in the instance's state dir, read-only twice over (`--readonly`, and
mode 0500 under df's own uid) so that an unused slot is not a writable host channel by accident. Raising the slot count
means changing `bindSlots` in `microvm-guest.nix` **and** `BIND_SLOTS` in `pkgs/by-name/scoite/package.nix`.

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
alongside `bin/microvm-run` in the same `scoite-guest-<type>` build once any share uses `proto = "virtiofs"`), and that
companion-process lifecycle normally only gets managed automatically under microvm.nix's systemd-managed
`microvm.host`/`microvm.vms.*` path, which `scoite` deliberately doesn't use (see below) — so the `scoite` wrapper
starts `virtiofsd-run` itself (backgrounded inside the same `systemd-run --user --unit`, so `scoite stop` tears down
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

Three narrow, deliberate exceptions travel in as fw_cfg credentials (never through the store):

**claude-code's OAuth credential (2026-08-22).** `~/.claude/.credentials.json` is copied from the host into
`/home/iosta/.claude/.credentials.json` on **every** launch, so a sandbox never has to run `claude login` of its own and
a long-stopped sandbox still starts with a live token (refreshing per launch beats letting a copy age in the persistent
home). df chose this over the alternative — persist the home and log in once per instance — for the zero-touch
ergonomics. State it plainly: this **is** a real credential inside the sandbox. A rogue agent can't escape the
filesystem boundary with it, but it can spend down the Pro subscription's quota and act as df against Anthropic. It is
the same trust tier as the auth-broker reachability described under "LLM access", just arriving by a different route. To
opt a launch out, remove the host file — no file, no credential.

**Git identity (2026-07-19)**: `~/.config/git/gitconfig.local` — df's git _identity_ (user.name/user.email + the
includeIf org lines), a sops secret on the host — **is** handed into the guest, because without it commits fail with
"Author identity unknown" (the guest's git config includes that path via `dev.git`, but iosta's ephemeral home had no
such file). It travels the same route as agent.env — wrapper exports `MICROVM_GITCONFIG` when the host file exists,
`microvm.credentialFiles.GITCONFIG_LOCAL` hands it over via fw_cfg (never in the store), and the guest's
`scoite-gitconfig` oneshot installs it to `/home/iosta/.config/git/gitconfig.local` (0600, ephemeral home — gone on
stop). It's name/email only — no key material; the org includeIf targets it references (`gitconfig.pgstar`, …) stay
absent in the guest and git silently skips missing includes, so sandbox commits always use the default identity.

**GitHub ssh aliases (2026-08-23)**: `~/.ssh/sshconfig.local` (a sops secret) is where df's per-account alias hosts live
— `donskifarrell.github.com`, `fingerfrens.github.com`, …, each `HostName github.com` plus its own
`IdentityFile ~/.ssh/<acct>_gh` + `IdentitiesOnly yes`. Real repos have remotes like
`git@donskifarrell.github.com:donskifarrell/obsidian.git`, so without that file a guest cannot even resolve the hostname
— agent forwarding works perfectly and `git fetch` still dies with `Could not resolve hostname`. That was the symptom
that prompted this: the key _was_ forwarded; the alias was missing.

The wrapper's `collect_credentials` therefore stages a tar (`ssh-conf.tar`, exported as `MICROVM_SSH_CONF`) holding the
config plus the **public** halves of the keys it names, and the guest's `scoite-ssh-config` oneshot unpacks it to
`/home/iosta/.ssh/` — `config.d/sshconfig.local` and `*_gh.pub`. `config.d` is wiped and rewritten on every boot, so a
block deleted on the host stops applying in the guest. It's picked up by the guest's `/etc/ssh/ssh_config`
(`programs.ssh.extraConfig`, which NixOS renders first, so it wins first-match-wins):

```
Match localuser iosta
  Include /home/iosta/.ssh/config.d/*
Host *
```

Two non-obvious constraints are baked into those three lines and the file modes, both found the hard way:

- **`~` is rejected in the system-wide config** (`bad include path ~/.ssh/config.d/*`, and ssh then terminates), so the
  path must be absolute — hence `Match localuser` to keep it scoped to iosta, and the trailing `Host *` to close that
  Match before the generated directives below it.
- **ssh parses `Include` eagerly, even for a user the `Match` excludes**, and refuses a config file owned by neither
  root nor the caller. With `config.d/sshconfig.local` owned by iosta, every `ssh` run _as root_ in the guest died with
  `Bad owner or permissions`. So `scoite-ssh-config` leaves `config.d` root-owned 0755 with the config 0644, which both
  users accept; the `.pub`s stay iosta's.

Why the pub halves are enough — and why they're needed: ssh resolves an `IdentityFile` whose _private_ half is missing
but whose `.pub` is present against the **agent**, so each alias still selects its own account's key while every private
key stays on abhaile. Dropping `IdentitiesOnly`/`IdentityFile` instead would be worse, not simpler: ssh would offer
every agent key and GitHub would authenticate as whichever account it recognised first — a silent wrong-account
"Repository not found" on a multi-account push. Public keys are public; the file list itself (which accounts df has) is
no more than the forwarded agent already exposes.

## Git auth: SSH-agent forwarding (2026-07-13)

`ssh scoite-<name>` forwards the host's ssh-agent (`services.ssh-agent`, the HM user service holding df's keys), so
`git push`/`pull`/`fetch` and `ssh -T git@github.com` just work inside a sandbox. Verified end-to-end: `ssh-add -l` in
the guest lists the host agent's keys, GitHub authenticates as df — with zero key files in the guest.

Three pieces, all small:

- **`ForwardAgent yes` for `Host scoite-*`** — lives in `dev.tools.scoite`'s homeManager module
  (`programs.ssh.settings."scoite-*"`), **not** in the per-instance blocks the wrapper writes into `~/.ssh/config.d/`.
  That placement is load-bearing: `ssh_config` is first-match-wins per keyword, and `core.network.ssh`'s `Host *` block
  (`ForwardAgent no`) is rendered **before** the `Include ~/.ssh/config.d/*` line, so a `ForwardAgent` in the wrapper's
  file would be silently shadowed. Home-manager renders non-`"*"` settings blocks before the `"*"` default block, so the
  aspect-level `Host scoite-*` wins. (HM-managed `~/.ssh/config` ⇒ takes effect on the next `nixos-rebuild switch`;
  until then `ssh -o ForwardAgent=yes scoite-<name>` does the same thing.)
- **Stable socket path in the guest** (`microvm-guest.nix` fish shellInit): sshd mints a fresh random agent socket per
  connection, so a long-lived session (a VS Code terminal, a multiplexer pane) would hold a dead `SSH_AUTH_SOCK` after
  an ssh drop + reattach. Every login re-points `~/.ssh/agent.sock` at its own live socket and sessions use the symlink
  — verified: kill the ssh ControlMaster, reconnect, panes' agent works again without restarting anything.
- **`github.com` in the guest's known*hosts — in \_two* files** (both from the one `githubHostKey` binding in
  `microvm-guest.nix`, GitHub's published ed25519 key). `programs.ssh.knownHosts` covers the ssh **CLI**, so a
  non-interactive agent's first `git fetch` can't stall on a host-key prompt (the ephemeral home would forget an
  accepted key on every stop anyway); it covers the `<acct>.github.com` aliases too, since they carry
  `HostName github.com`, which is what ssh checks the host key against. But that option only writes
  `/etc/ssh/ssh_known_hosts`, and **libgit2 — the git client inside `nix` — reads `~/.ssh/known_hosts` and nothing
  else**, so a tmpfiles `C` rule seeds `/home/iosta/.ssh/known_hosts` as well (copy-if-absent, so a host iosta accepts
  later still survives the next boot). Without it every `nix`/`devenv` flake-input fetch fails; see the quirk below.
- **`User git` on the alias blocks** (in `~/.ssh/sshconfig.local`, the sops secret). Without it ssh sends the local
  username — `iosta` in a guest, `df` on abhaile — and GitHub answers `Permission denied (publickey)` even though the
  right key was offered and accepted-shaped. Remotes written `git@…` were always fine; this only makes the bare forms
  (`ssh -T github.com`, `ssh -T donskifarrell.github.com`) work too.
- **The alias config itself** (`scoite-ssh-config`, above) — forwarding alone is not enough for a remote that uses one
  of df's per-account alias hostnames.

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

The launch banner's `code --remote ssh-remote+scoite-<name> /workspace` line works for real now (equivalently: F1 →
"Remote-SSH: Connect to Host…" → `scoite-<name>` → open `/workspace`) — a full editor session inside the sandbox, files
edited as if local, integrated terminals landing in the guest as iosta. Four pieces made it work:

- **Guest: `programs.nix-ld.enable`** (`microvm-guest.nix`). Remote-SSH downloads a prebuilt server into
  `~/.vscode-server` whose node binary is linked against `/lib64/ld-linux-x86-64.so.2` — a path that doesn't exist on
  NixOS, so the server died on launch. nix-ld provides that loader; no `NIX_LD` env plumbing is needed for sshd exec
  sessions (where profile sourcing is shaky) because nix-ld falls back to
  `/run/current-system/sw/share/nix-ld/lib/ld.so` when the var is unset. The bootstrap's download tooling (curl/wget,
  tar) was already in the guest via `shell.bundles.base` / the NixOS base path.
- **Guest: `~/.vscode-server` has to persist.** Without that, every boot re-downloaded the server + remote extensions
  (tens of MB, ~a minute before the editor connects). It originally had a dedicated `vscode-server.img` volume; since
  the whole home is a persistent volume (2026-08-22) it just lives there and that volume is gone. Fresh ext4 mounts
  root-owned, so a root oneshot (`scoite-home-perms`, formerly `vscode-server-volume-perms`) chowns the mount root to
  iosta before home-manager activation and sshd start. A tmpfiles `z` rule was tried for the old volume and **does not
  work**: tmpfiles refuses to touch a root-owned path under a user-owned home ("Detected unsafe path transition
  /home/iosta → /home/iosta/.vscode-server", seen in a live guest's journal) — the refusal triggers on exactly the state
  the rule exists to fix. The symptom was VS Code dying with "Connecting with SSH timed out" (the bootstrap piped over
  ssh can't write into `~/.vscode-server`, produces no output VS Code recognises, and the extension just waits out its
  `remote.SSH.connectTimeout` — now set to 60s in `dev.vscode`, since a first-connect server download over SLIRP can
  also outlast the 15s default).
- **Host: `dev.vscode` changes.** The `ms-vscode-remote.remote-ssh` extension is now declared, and
  `remote.SSH.configFile` was re-pointed from `~/.ssh/sshconfig.local` to `~/.ssh/config`. The old value predated the
  HM-managed ssh config and was the silent killer: VS Code read _only_ that file, which contains no
  `Include ~/.ssh/config.d/*` line — so the `scoite-*` Host blocks the wrapper writes resolved fine for the ssh CLI but
  were invisible to VS Code. `~/.ssh/config` Includes both `sshconfig.local` and `config.d/*`, so nothing was lost.
- **Host: `remote.SSH.useLocalServer: false` — required because the guest's login shell is fish.** In the default
  local-server mode, Remote-SSH opens a plain ssh session (no remote command) and pipes its install script into the
  **login shell**. That script is bash, and fish rejects it at _parse_ time (`fish: Unsupported use of '='`, exit 127)
  without executing a single line — VS Code never sees its start marker and reports only "Connecting with SSH timed out"
  (verified by piping the script's opening lines into a guest by hand). With `useLocalServer: false` the extension
  instead runs `ssh <host> sh` — an explicit remote command, so sshd invokes `fish -c sh` and the script runs under `sh`
  regardless of the login shell. Any future guest whose user shells out of bash/zsh needs this same setting; the
  alternative (bash as iosta's login shell, exec'ing fish when interactive) was rejected because the guest's agent.env
  exports and `SSH_AUTH_SOCK` glue live in fish's config. Paired with it, two more `dev.vscode` pieces:
  - `remote.SSH.remotePlatform = { "scoite-*" = "linux" }` — without a matching entry the extension asks for the
    platform on the first connect to each new instance. The map keys support `*` wildcards (per the extension's own
    setting description), and the extension notes this setting will become _required_ when `useLocalServer` is off.
  - **settings.json is installed as a mutable file, not HM's usual read-only symlink** (a `home.activation` step copies
    the declared JSON on every switch). Reason: in `useLocalServer: false` mode the extension flags `storePlatform` on
    _every_ successful connect (`tryInstall` in extension.js, unconditional), and its save guard checks only for an
    **exact** hostname key — the wildcard satisfies resolution but never the guard — so after every connect it writes
    `remotePlatform["scoite-<name>"] = "linux"` into `settings.json`. Against a read-only symlink that write fails and
    nags every time; against the mutable file it succeeds silently, and the next `nixos-rebuild switch` resets the file
    to the declared state (the accumulated exact entries are redundant with the wildcard anyway). Side benefit: ad-hoc
    UI settings tweaks stop erroring too — they now last until the next switch.

Terminals inside a VS Code remote window are plain fish, not herdr: the autostart is gated on `SSH_TTY`, which VS Code's
exec-channel sessions don't set — deliberate, same as the qemu console. They get `/run/agent.env` exports like any other
fish session, and the forwarded ssh-agent via the stable `~/.ssh/agent.sock` symlink whenever some agent-forwarding ssh
session is (or has been) connected — VS Code's own connection uses `~/.ssh/config` now, so it forwards the agent itself
per the `Host scoite-*` block.

Rollout gotchas: the host side (extension + setting) needs a `nixos-rebuild switch`; the guest side is rebuilt fresh on
every `scoite` launch, so an **already-running** sandbox must be stopped and relaunched to pick it up. First connect per
instance still downloads the server once; the volume makes every later connect warm.

## Why imperative, not declarative/host-managed

microvm.nix supports two modes: (1) `microvm.host.enable` + `microvm.vms.*` — host registers VMs as systemd services,
meant for always-on, host-known VMs; (2) build a guest's `config.microvm.declaredRunner` directly and exec it
(`nix run .#name`) — the documented "imperative" pattern (see `microvm.nix`'s own `flake-template/flake.nix`). `scoite`
needs mode 2: the project path is only known at invocation time, for an arbitrary folder, not a fixed list of host-known
VMs. This is also why no `microvm.nixosModules.host` import exists anywhere in this repo — it's simply not needed for
mode 2.

## Networking

A guest has **two** NICs, and the split is the whole design (2026-08-25):

| NIC    | what                                              | carries                                                                                        |
| ------ | ------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `eth0` | qemu SLIRP (`type = "user"`)                      | the **default route** — all egress, plus abhaile's loopback services at the gateway `10.0.2.2` |
| `eth1` | a tap on the host bridge `scoitebr0` (10.77.0/24) | a real address the host can reach **inbound**, and the guest's mDNS `<name>.local` identity    |

SLIRP was there first and keeps everything that ever worked working: llama-server on `10.0.2.2:8080`, harmonia on
`:5000`, and the internet. The bridge NIC takes an address from a dnsmasq of its own and **nothing else** —
`UseRoutes/UseDNS/UseNTP/UseHostname = false` — so it cannot race SLIRP for egress. It exists because a forwarded port
is not an identity: mDNS names (below) and LAN exposure both need the guest to be a real host on a real network.

Host side (`virtualisation/microvm-host.nix`): `scoite-bridge.service` creates the bridge with plain iproute2 (abhaile's
networking is NetworkManager's, and this bridge wants to be invisible to it), `dnsmasq-scoite.service` serves DHCP only
(`--port=0`, so it can never race systemd-resolved for `:53`), the interface is trusted in the firewall, and qemu's
setuid `qemu-bridge-helper` (from the libvirtd module, whose `allowedBridges` list this extends) is what lets an
unprivileged `scoite` attach a tap. Each instance's MAC is derived from its name (`mac_for`) and passed per launch, so
leases are stable and no two guests collide.

Two traps, both found the hard way:

- **Tailscale hijacks the subnet.** With `--accept-routes` and an exit node selected, tailscale's rule at priority 5270
  outranks the main routing table and its table 52 holds a route for 10.77.0.0/24 — the host sent packets for its own
  guests down `tailscale0`. DHCP kept working (it is L2), so the bridge looked healthy while every ping/ssh/curl
  black-holed. `scoite-bridge.service` installs `ip rule add to 10.77.0.0/24 lookup main priority 5000` to win.
- **Do not delete the bridge while guests run.** `ip link del` silently detaches every enslaved tap; the sandboxes stay
  up (SLIRP is separate) but vanish from the bridge until restarted. The unit's `preStop` therefore removes only the ip
  rule.

**Every instance owns a loopback address of its own** — `127.<a>.<b>.1`, hashed from the instance name by `free_addr`,
persisted as `ADDR` in `~/.local/state/scoite/<name>/config` and shown by `scoite list`. All of `127.0.0.0/8` is bound
to `lo` on Linux, so any of it is bindable unprivileged with no `ip addr add` and no root. Every `microvm.forwardPorts`
entry sets `host.address` to it, which buys three things at once:

- **Guest ports map 1:1.** A dev server on `:5173` in the guest is `http://127.<a>.<b>.1:5173` on the host — no
  renumbering to remember. SSH is therefore a fixed `2222` on every instance rather than a hashed per-instance port.
- **No collisions.** A guest's `:8080` is `127.<a>.<b>.1:8080`, which does not touch abhaile's llama-server on
  `127.0.0.1:8080` (nor harmonia `:5000`). `free_addr` deliberately avoids `127.0.x.y` for exactly this reason, and two
  sandboxes never share an address (it checks the other instances' configs and bumps).
- **It is actually host-only.** `microvm.forwardPorts` defaults `host.address` to `""`, which qemu renders as _bind all
  interfaces_ — before 2026-08-22 every sandbox's forwarded ports, ssh included, were offered to the LAN, contradicting
  the design intent stated above. Loopback is not routable off-box.

A wide set of common dev ports (3000–3009, 4000–4009, 5000–5009, 5173–5182, 6006, 8000–8009, 8080–8089, 9000–9009) is
forwarded on **every** launch, so viewing a guest web server usually needs no flag and no restart at all. `--port N`
adds one outside that set at launch; `scoite expose [<name>] <port>` adds one to an **already-running** guest via qemu's
HMP `hostfwd_add` over the QMP socket (`scoite unexpose` removes it), and persists it so a restart keeps it.

The default set lives in the CLI (`DEFAULT_DEV_PORTS`), not in the guest module, because which of those ports can
actually be bound depends on live host state: **qemu aborts the entire VM over a single failed `hostfwd` rule** ("Could
not set up host forwarding rule ..."), so anything a host process is holding on a _wildcard_ address must be dropped
before launch rather than allowed to take the sandbox down with it. `effective_ports` does that filtering per launch
(reporting what it skipped) and feeds the result to `MICROVM_PORTS`; the guest module only de-duplicates and keeps the
ssh port from being forwarded twice, the other two shapes qemu refuses to start with. A listener on a _specific_ address
never blocks anything — that is the payoff of per-instance addresses.

**The guest runs no firewall** (`networking.firewall.enable = false` in `microvm-guest.nix`). The reasoning was SLIRP's:
one inbound path, a `hostfwd` rule qemu holds on the host, so the forwarded-port list _is_ the access-control list and
an in-guest firewall is a second, invisible one to keep in sync. With the bridge NIC there is now a second inbound path
— but only from abhaile itself (the bridge is not routed anywhere, and LAN reach is the explicit, per-port
`scoite expose --lan`), so the trade still holds: what a sandbox offers is decided on the host, in one place. Nothing
used to set this, so guests ran NixOS's default: enabled, port 22 only (from `services.openssh.openFirewall`), **policy
DROP**. That silently black-holed every `scoite --port N` ever used — the host-side connect succeeded (qemu accepts
before it dials the guest), the request then hit a DROP with no RST, and `curl` hung forever with no error on either
side, while `curl` _inside_ the guest worked (the `lo` accept rule is first in the chain). Ports nothing forwards stay
unreachable for the solid reason that qemu is not listening on them.

Inside the guest, both NICs are configured by **systemd-networkd** (`networking.useNetworkd`, one `.network` file each)
— not NetworkManager, which `roles.default` stopped shipping on 2026-07-14 (a desktop network daemon was the single
biggest guest boot-time/RAM cost). Interface names are the unpredictable kind on purpose
(`usePredictableInterfaceNames = false`): with two NICs the only thing a _shared_ system closure can match on is
interface order, since the bridge MAC is per-instance. The bridge NIC also sets `ClientIdentifier = "mac"` — networkd's
default DUID comes from `/etc/machine-id`, which every guest of a type shares, so dnsmasq handed them all the same lease
until this was set. `wait-online.anyInterface` lets `network-online.target` — the gate for `scoite-workspace-init` —
fire as soon as that one link is up. (Den's `primary-user` battery still puts iosta in a `networkmanager` group that no
longer exists in the guest; NixOS silently drops unknown groups, harmless.)

## Names: `<name>.local` (mDNS)

A running guest answers to **`scoite-<name>.local`** from abhaile: `ssh scoite-myproject.local`,
`http://scoite-myproject.local:5173`, `curl http://scoite-myproject.local:6767/api/health`. `scoite list` prints the
name and the address it resolves to.

- Guest side: `services.resolved` with `MulticastDNS = true` on the bridge NIC publishes the hostname — which the
  `INSTANCE` boot credential has already set to the instance name, so the shared closure stays name-free. No avahi in
  the guest.
- Host side: `core.network.avahi` with `nssmdns4`/`nssmdns6` **on**. Without those, `/etc/nsswitch.conf` carries no mdns
  entry and glibc cannot resolve any `.local` name — `avahi-resolve` works while `getent`, ssh, curl and browsers do
  not. That was the state until 2026-08-25.
- `getent hosts <name>.local` answers with the IPv6 link-local address first; clients that try both (ssh, curl) do not
  care, but use `getent ahostsv4` when you want the v4 address.
- `scoite rename` moves the name live: it sets the guest's hostname with `hostname(1)` (not `hostnamectl` — the guest
  has a _static_ hostname, `sandbox`, baked into the shared closure, and systemd ignores a transient name whenever a
  static one exists) and restarts `systemd-resolved`, which otherwise keeps announcing the old name. The old name stops
  resolving once the host's mDNS cache expires (~1 minute).

## Exposing a service to the LAN

Everything above is host-only. `scoite expose [<name>] --lan [--lan-port <n>] <port>` opens exactly one port, for one
sandbox, to the rest of the network, and `scoite unexpose --lan <port>` closes it. Nothing is exposed by default.

- A root helper, `scoite-lan add|del|list` (installed by `virtualisation/microvm-host.nix`), installs an **iptables
  DNAT** on the host's default-route interface to the guest's bridge address, tagged with a comment so it can be removed
  precisely. The CLI stays unprivileged and calls it through `sudo`.
- A **MASQUERADE** on the way into the bridge is not optional: a guest's default route is SLIRP, so without SNAT it
  answers a LAN client down SLIRP and the connection hangs.
- The URL is abhaile's own name (`http://abhaile.local:<port>`), not the guest's: guest `.local` names are published on
  the sandbox bridge only, and abhaile's LAN is wifi, where bridging a guest's MAC onto the LAN is not possible.
- Exposures are recorded per instance (`LAN_PORTS` in its config), shown in `scoite list`'s `LAN` column, removed on
  `stop`/`rm` and re-applied automatically after the guest boots on `start`. A LAN port already claimed by another
  sandbox is refused — pick another with `--lan-port`.

**If a LAN client cannot reach abhaile at all**, check tailscale before anything else: with an exit node selected and
`ExitNodeAllowLANAccess: false`, _every_ reply to a LAN address goes down the tunnel and inbound connections stall.
`services/tailscale.nix` now passes `--exit-node-allow-lan-access` (a no-op when no exit node is in use).

## Memory: a ceiling, not a reservation

`--mem` defaults to 32768 (MiB) for `dev` and 4096 for `minimal`. Those are deliberately generous because they are
**caps**: qemu only allocates guest pages as they're touched, and the guest runs a virtio-balloon that microvm.nix
configures with `free-page-reporting=on` (`microvm.balloon = true` in `microvm-guest.nix`) — memory the guest frees
(e.g. page cache dropped after a big `nix build`) is returned to the host automatically, no QMP babysitting,
`deflate-on-oom` on. The one fixed cost that does scale with the ceiling is the guest kernel's `struct page` array,
~1.5% of `mem` (~500M at 32G) — lower `--mem` for many concurrent idle sandboxes.

## Host identity in the guest, kept current

Three host files reach a guest as qemu `fw_cfg` systemd credentials — read at VM start, never copied into the
world-readable `/nix/store` — and **all three are also re-pushed into a _running_ guest** by `scoite creds` (which
`scoite ssh` runs on every attach, plus a 10-minute host timer):

| credential        | from                                                    | installed by                  | what it gives the guest                       |
| ----------------- | ------------------------------------------------------- | ----------------------------- | --------------------------------------------- |
| `AGENT_ENV`       | `~/.config/scoite/agent.env`                            | fish exports `/run/agent.env` | cloud LLM API keys                            |
| `SSH_CONF`        | `~/.ssh/sshconfig.local` + the **public** keys it names | `scoite-install-ssh-conf`     | per-account git remotes (`<acct>.github.com`) |
| `GITCONFIG_LOCAL` | `~/.config/git/gitconfig.local`                         | `scoite-install-gitconfig`    | git identity                                  |

A fourth channel existed until 2026-09-08: df's `~/.omp/agent` config tree, staged into
`~/.local/state/scoite/<name>/omp-conf.d/` and 9p-mounted at `/run/scoite-omp`. It went with omp itself. **The reason it
was a share and not a credential is still worth keeping**: systemd refuses any credential larger than **1 MiB**, and the
`skills-vendor` tree took the tar to 1.3 MiB — at which point qemu still passed it, systemd dropped it, and every new
sandbox came up with an empty config and no error anywhere (2026-08-26). Anything host→guest of that size wants a share
or a `scoite bind`, not a credential. If pi's config ever needs to ride in, `scoite bind ~/.pi` is the ready-made answer
— live in both directions, no staging, no ceiling.

Also worth keeping from that episode: stage from an **allow-list**, never a deny-list. `~/.omp/agent` held session
databases, logs and a broker token next to the config; a deny-list ships whichever of those the tool adds next.

The installers are commands, not inline unit scripts, precisely because they run twice — at boot and on every push. The
units invoke them by **absolute store path**: a systemd unit's PATH does not include `/run/current-system/sw/bin`, and
calling them by name failed at boot with "command not found" while the login-shell push path kept working.

## LLM access for the agent harness

Two lanes, both wired in `microvm-guest.nix`:

**Local (llama-server):** qemu's usermode gateway (`10.0.2.2` from the guest) forwards to the host's loopback interface,
so abhaile's llama-server on `127.0.0.1:8080` (`modules/den/aspects/services/llm.nix`) is reachable from inside every
scoite guest at `http://10.0.2.2:8080/v1` with **no change** to llm.nix's bind address. It is an OpenAI-compatible
endpoint with no auth, so pointing an agent at it is one provider entry in that agent's own config; the base URL is
`guestBaseUrl` in `modules/den/aspects/services/_llm-models.nix`, alongside the model ids and context sizes
llama-server's router presets are generated from. Keep whatever you declare guest-side in step with that file — a
context window larger than the server's is invisible until a request hangs.

Until 2026-09-08 the guest generated an omp `models.yml` from exactly that data at every boot. Nothing does now; a guest
agent's provider config is the agent's own business (`scoite bind ~/.pi`, or a file in `/workspace`).

**Cloud:** put `KEY=value` lines (e.g. `OPENAI_API_KEY=…`, `ANTHROPIC_API_KEY=…`) in `~/.config/scoite/agent.env` on the
host (0600; create it yourself — nothing manages it). `scoite` copies it into a per-launch temp file
(`~/.local/state/scoite/<name>/agent.env`, 0600), passes the _path_ to the guest build, and `microvm.credentialFiles`
turns it into a qemu `fw_cfg` systemd credential whose contents are read at VM start — **key material never enters the
world-readable `/nix/store`** on either side (the whole design constraint; a Nix path _literal_ instead of a string
would silently defeat it by copying the file to the store at eval time). In the guest, a oneshot installs the file at
`/run/agent.env` (iosta, 0600, tmpfs — gone on stop) and fish exports its lines into every session. No lines at all → no
credential → local provider only.

claude-code is the exception that needs no key: df's live OAuth credential (`~/.claude/.credentials.json`) rides in as
the `CLAUDE_CREDS` credential, refreshed on every launch, so a sandbox never runs `claude login` of its own.

**Keeping a running guest current.** `/run/agent.env` is written once, at the guest's boot, so a key rotated on the host
afterwards leaves a running sandbox holding a dead one. **`scoite creds [<name>|--all]`** re-stages agent.env (and the
ssh/git identity files) and writes them into a _running_ guest over ssh; `scoite ssh` does it silently on every attach,
and a host-side `systemd --user` timer (`scoite-creds`, 10 min, defined in `dev.tools.scoite`) covers headless sandboxes
nobody attaches to. Only _new_ shells in the guest see the refreshed value — fish exports agent.env at shell start —
which is enough, since an agent reads its credentials at process start. The push always runs with `-o ForwardAgent=no`:
the guest's login shell re-points `~/.ssh/agent.sock` at whatever connection it sees, and a scripted connection's
forwarded socket dies with that connection, so a forwarding push would leave long-lived guest sessions holding a dead
socket. Verified: after a push, the guest's `agent.sock` still points at the previous, live socket.

**Dropped 2026-09-08: the omp auth-broker.** `dev.tools.omp-auth-broker` ran `omp auth-broker serve` on the host
(`127.0.0.1:8765`) as a shared credential store, so every guest could use df's Anthropic Pro subscription without
holding the OAuth token itself — the broker's own refresher kept sessions alive past the point where the sandbox that
could have refreshed the token was gone. It went with omp. Two things it taught, if the pattern ever comes back:

- Anthropic rotates the refresh token on every use, so **two holders of one grant invalidate each other** — a duplicate
  stale credential row will keep retrying until the provider disables the whole credential. Watch for duplicate rows,
  not just failures.
- A broker bearer token is a skeleton key to every credential it holds, reachable from anything on the loopback path —
  in practice, every sandbox. A rogue agent can't escape the filesystem sandbox through it, but it can spend down a
  subscription's quota. Mind what you auto-approve in a sandbox with a real subscription behind it.

## UI validation: headless Chromium (2026-08-21)

An agent that writes a web UI has to be able to _look_ at it. `dev.tools.headless-browser` (in `roles.sandbox.dev` and
up, so guest-only — df's real hosts get graphical browsers from `apps.bundles.browsers`) puts three entry points in the
guest, because agents reach for different ones:

- **`headless-chromium <url>`** — a `writeShellScriptBin` wrapper around `pkgs.chromium` with
  `--headless=new --disable-gpu --disable-dev-shm-usage --no-first-run --no-default-browser-check` already applied, e.g.
  `headless-chromium --screenshot=/workspace/ui.png --window-size=1280,800 http://127.0.0.1:5173`.
- **playwright / puppeteer from the project's own `node_modules`** — the aspect exports `PLAYWRIGHT_BROWSERS_PATH`
  (nixpkgs' patchelf'd browser set), `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD`, `PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS`,
  `PUPPETEER_SKIP_DOWNLOAD`, `PUPPETEER_EXECUTABLE_PATH`, `CHROME_PATH`, `CHROME_BIN` as home-manager session variables,
  so those tools find a browser that runs instead of downloading one that can't (a browser fetched by
  `npx playwright install` is dynamically linked against paths NixOS doesn't have). Verified to reach non-interactive
  `ssh <guest> <cmd>` sessions, not just interactive logins.
- **`playwright-mcp`** — the MCP server, so claude-code/pi can drive the browser as a tool rather than by shelling out.
  Not registered anywhere by default; per project it's
  `claude mcp add playwright -- playwright-mcp --headless --isolated`.

The browser runs _inside_ the guest, so it reaches the project's dev server on plain `127.0.0.1` — the forwarding in
[Networking](#networking) only matters when a human wants to look from the host.

Two supporting decisions:

- **Fonts.** The aspect's `nixos` key sets `fonts.enableDefaultPackages = true`. Without any fonts installed, every
  headless screenshot renders as tofu boxes and visual validation is worthless. It costs abhaile nothing extra — the
  same default set is already in its store via `core.desktop.fonts`. Confirmed by screenshot: Latin, CJK and colour
  emoji all render (185 fonts in `fc-list` in the guest).
- **Chromium only.** `playwright-driver.browsers` is overridden with `withFirefox = false; withWebkit = false;` — the
  full set adds ~1G of guest closure for browsers nothing here asks for. Flip them on in the aspect if a project needs
  cross-browser runs. Even so, the browsers are the bulk of what this aspect costs: the guest's system closure went 6.2
  GiB → 8.5 GiB (playwright's chromium 804 MiB + headless-shell 261 MiB, plus `pkgs.chromium` and its desktop-library
  deps — most of which abhaile's store already had for df's own browsers).

Gotchas:

- **Version coupling.** `PLAYWRIGHT_BROWSERS_PATH` is a linkFarm of browser _revisions_ pinned by the nixpkgs driver
  version (`chromium-1228` for playwright 1.61.1). A project pinning a different npm `playwright` will look for a
  revision that isn't in it and fail. Pin the project to the guest's version (`playwright --version`), or let that
  project fetch its own browsers inside a devenv/FHS environment.
- Chromium's namespace sandbox works in the guest as-is — `--no-sandbox` is **not** needed and shouldn't be added
  reflexively.

Verified end-to-end on 2026-08-21 by booting a sandbox on a scratch project: `headless-chromium` and
`playwright screenshot` both captured correct PNGs of a `file://` page and of one served over `busybox httpd` on
`127.0.0.1:8080`, and `playwright-mcp` starts.

## `xdg-open` for a machine with nothing to open with (2026-09-04)

A sandbox has no desktop, so nothing in the guest closure provides `xdg-open` — and a tool that wants to show a human a
URL does not degrade when it is missing, it dies. `pi`'s stats-dashboard extension is the case that surfaced this: it
starts a local server and hands the URL to `xdg-open`, the spawn fails with `ENOENT`, and because that happens in a
callback the uncaught exception takes the whole `pi` process down, losing the session.

`shell.xdg-open` (in `roles.sandbox.minimal`, so both tiers) answers that with a `writeShellScriptBin` that never opens
anything and never fails — it tells the human the URL instead, and exits 0. Guest-only: df's real hosts keep the real
`xdg-open` from xdg-utils. It also sets `BROWSER=xdg-open` as a session variable, so the tools that consult `$BROWSER`
first (gh, python's `webbrowser`, npm's `open`) land on the same shim rather than on their own assorted failure modes.

Two details it exists for, both of which a naive `echo "$1"` gets wrong:

- **It writes to the user's ptys, not to its own stdio.** The callers that matter spawn it as pi does —
  `spawn(cmd, args, { detached: true, stdio: "ignore" })` — with no stdio and no controlling terminal, so anything
  printed to stdout/stderr goes to `/dev/null`. An ssh pty is mode `0620` owned by the session user, so the shim writes
  the message to every `/dev/pts/*` it can write to (skipping its own stderr device, so the ordinary interactive case
  doesn't print twice). `$XDG_STATE_HOME/xdg-open.log` catches whatever nobody saw live. Verified with a detached,
  `stdio`-ignored call from one ssh session landing in another's terminal.
- **For a loopback URL it prints the tunnel command.** The URL a guest tool prints is `127.0.0.1:<port>` _inside the
  guest_, which the forwarded ports do not reach — qemu's `hostfwd` rules point at the user-net guest address, not at
  the guest's loopback (see [Networking](#networking)). The thing that does work is an ssh tunnel over the connection
  the human already has, so the shim prints `ssh -N -L <port>:127.0.0.1:<port> <guest>` and lets them open the URL in a
  browser on abhaile. `hostname` in a guest is set from the `INSTANCE` credential at boot and is exactly the host-side
  ssh alias (`scoite-bbm`), so it can be quoted straight into that command.

## Known quirks

- **`invalid or unknown remote ssh hostkey` from `nix`/`devenv` is a `~/.ssh/known_hosts` problem, not a TLS one**
  (fixed 2026-08-28). The full error —
  `connecting to remote 'https://github.com/cachix/devenv.git': invalid or unknown remote ssh hostkey`, which broke
  every `devenv update` in a guest — names an **https** URL and an **ssh** host key, and both halves are literally true:
  df's gitconfig (pushed in by `scoite creds`) carries `url."git@github.com:".insteadOf = "https://github.com/"`, so nix
  rewrites each `github:` flake input to ssh before libgit2 dials it, and libgit2 then fails the host-key check against
  a `~/.ssh/known_hosts` that did not exist. It is libgit2's `GIT_ECERTIFICATE` text, which is why the message reads
  like a CA-bundle failure; `SSL_CERT_FILE` / `NIX_SSL_CERT_FILE` change nothing. `/etc/ssh/ssh_known_hosts` doesn't
  help either — libgit2 never reads it. Hence the seeding rule above. Note that the ssh **CLI** was unaffected
  throughout, so `ssh -T git@github.com` succeeding is no evidence that a `nix` fetch will.
- (Historical, fixed 2026-07-13: when the guest ran df's full HM identity via `roles.dev`, it also inherited the
  `scoite` binary itself and a spare host-side auth broker per boot. The iosta/`roles.sandbox.*` guest identity includes
  neither — a guest tier is a deliberate slice, not df's profile.)
- **An interactive login waits for `scoite-workspace-init`** rather than racing it. The boot unit is already evaluating
  the project's devenv/flake, and direnv in the login shell would start a _second_ evaluation of the same project
  against the same shared `/workspace/.devenv`. Two concurrent devenv bootstraps do not survive that: seen 2026-08-26 on
  `scoite new --ssh` into a large monorepo, where the pre-build took four minutes, the login raced it, and devenv failed
  with `Failed to get shell attribute` inside a nixpkgs-bootstrap trace that says nothing about the real cause. The wait
  is bounded at 20 minutes so a wedged pre-build cannot make the sandbox unreachable.
- **(Historical, moot since omp was dropped on 2026-09-08.)** The guest used to generate an agent `models.yml` from
  `modules/den/aspects/services/_llm-models.nix` on every boot. Two lessons survive it. It was first seeded with a
  tmpfiles `C` (copy-if-absent) rule, so a guest kept whatever it first received — including, briefly, a version whose
  list items had lost their indentation (a Nix `''` string strips the _common_ indent, and the interpolated list sat
  shallower than its surroundings) that the agent rejected with a yaml parse error: **derived config must be rewritten
  every boot, not seeded once**, and when changing a generator, read the **built** file rather than eyeballing the Nix.
  The other: a first-run wizard has to be disabled through the tool's own config writer, not by hand-editing YAML.
- **`scoite` is not in the devshell** (removed 2026-08-26). It used to be, and it shadowed the home-manager copy for
  anyone standing in `~/.dotfiles`, pinned to whatever store path direnv last evaluated — so `sc` meant different things
  in different directories and "verified" fixes could be running hours-old code.
- **File capabilities cannot be set on `/workspace`.** virtiofsd runs unprivileged (as df), so `security.capability`
  xattrs are refused: a project whose devenv does `sudo setcap cap_net_bind_service=+ep …` on a binary under the
  workspace gets `Invalid file '…' for capability operation`. It is non-fatal (the task fails, the shell is fine) and
  only matters for binding ports < 1024 inside the guest — bind a high port, or keep the binary on the guest's own
  filesystem. The unit's PATH does include `/run/wrappers/bin` now, so the `sudo` itself resolves.
- **`scoite ssh` failing with `Permission denied (publickey)` almost always means the host ssh-agent is empty**, not
  that the guest is broken. The guest authorizes df's public key and nothing else, and by design no private key exists
  guest-side; `ssh-add -l` on the host is the first thing to check (the CLI prints it when a wait times out).
- `nix build .#scoite-guest-<type>` needs `--impure` and `MICROVM_WORKDIR` set in the environment first (the `scoite`
  CLI always does both; don't invoke the flake output directly except for debugging). Without it, the guest module falls
  back to sharing `/var/empty` as `/workspace` and prints a `lib.warn` rather than hard-failing — a hard assertion here
  would break `nix flake check` for everyone, always, since flake check evaluates
  `nixosConfigurations.*.config.system.build.toplevel` purely (no `--impure`).
- A crashed/interrupted launch can orphan the `virtiofsd` process for that instance — systemd's cgroup teardown doesn't
  reliably reap a backgrounded child when the unit's main process (qemu) exits/errors on its own rather than being
  stopped via `scoite stop`. The orphan holds `virtiofsd`'s pid-file lock, so every subsequent relaunch fails
  immediately with "Resource temporarily unavailable" until it's cleared. `scoite` defensively `pkill`s any matching
  stale `virtiofsd` and removes its lock file before each launch. Note the socket path it matches on is **absolute**:
  now that every guest's hostname is the static string `sandbox`, microvm.nix names every instance's virtiofs socket
  identically, and a relative pattern would match siblings.
- The transient unit is launched with `systemd-run --collect`, so a nonzero exit (a crash) auto-unloads it instead of
  sitting "failed" — without that, relaunching the same `<name>` would hit "Unit … was already loaded or has a fragment
  file" until a manual `systemctl --user reset-failed`.
- `scoite` is home-manager-installed, so changes to `pkgs/by-name/scoite/package.nix` don't reach `$PATH` until the next
  `nixos-rebuild switch`/`test` — a plain `git commit`/`nix build` isn't enough. Easy to forget and then debug a "fix"
  that was never actually deployed.
- The console (`scoite -f`'s own foreground output — `ssh`'s fallback if SSH itself is broken) logs in as `iosta` /
  password `iosta`. Autologin was tried first and rejected (silently dropping into a shell on every launch); a throwaway
  typeable password — same pattern as `virtualisation/vm-login.nix`'s debug VM — was the alternative. The console is a
  plain fish shell, usable for debugging when ssh itself is broken.
- `scoite list`'s NAME column shows the full `scoite-<name>` identity, which is also the SSH alias, the unit name and
  the mDNS name. Subcommands accept either spelling (`mono` or `scoite-mono`).
- **herdr decides where a pane starts, not your shell.** Its `terminal.new_cwd` policy defaults to `$HOME` when a pane
  has no source workspace, whatever the launching shell's cwd was, and it persists that session in
  `~/.config/herdr/session.json` on the guest's home volume — which survives stop/start, so a stale session can outlive
  the config change meant to fix it. Set `[terminal] new_cwd = "/workspace"` if panes keep landing in `/home/iosta`.
- Any **electron** app launched from an agent/CLI session inherits `ELECTRON_RUN_AS_NODE=1` when the agent itself runs
  inside electron, and fails with "Electron failed to install correctly". `env -u ELECTRON_RUN_AS_NODE` fixes it;
  nothing is wrong with the package.
- State dirs created before the 2026-08-22 rework have no `config` file and list as type `legacy`; they are not
  startable (the volume layout and guest hosts changed underneath them). `scoite rm <name>` each of them.
- The old `name_for` piped `basename` through `tr -c 'a-zA-Z0-9' '-'`, which turned the trailing newline into a second
  dash — hence the `myproject--a1b2c3d4` names in old state dirs. Fixed (`tr -d '\n'` first), which is part of why old
  instances don't carry over.

## Not built yet (tracked in TASKS.md)

- Network egress allowlisting inside the guest (smolvm has a good pattern for this: default-deny + an explicit
  allowed-hosts list) — deliberately deferred, see TASKS.md S20.
- Replacing the read-write `hostkey` 9p share with a `microvm.credentialFiles` entry — removes a virtio device and
  closes "guest root can read/corrupt the SSH host key shared by all instances" (in-guest root is trivially reachable:
  iosta is in wheel with password `iosta`).
