# AON infrastructure — `scoite` task plan

Project tracker for the goals in [GOAL.md](GOAL.md): rename `sandvm` → **`scoite`** (alias `sc`), cut the guest tiers to
**two** (`minimal`, `dev`), give every sandbox a real **DNS name** and **LAN-reachable services**, and make host
credentials/config (omp auth, SSH keys, omp config, nix store) **propagate live** into running guests.

Rules of engagement (df, 2026-08-24):

- **One step at a time.** A step is not started until the previous one is verified and ticked.
- Every step carries an explicit **Verify** block. Run it, paste/record the result, then mark the row `done`.
- Status values: `todo` · `wip` · `blocked` · `done` · `n/a`.
- Anything learned that outlives the step goes into `CLAUDE.md` or `docs/microvm-sandbox.md`, not here.

**Decisions taken (df, 2026-08-24):**

- **Existing sandboxes: deleted, recreate fresh.** Both pre-rename instances were removed in S1, so **S2 needs no
  state-migration code** — `~/.local/state/scoite` starts empty. (Their small agent config dirs were archived to
  `~/.local/state/scoite-preserve/*.tar.gz` first; host workspaces were never touched.)
- **Networking: add a second NIC on a host-managed NAT bridge, keep SLIRP.** SLIRP stays the default route and the path
  to abhaile's `10.0.2.2` services; the bridge NIC gives each guest a routable address + mDNS identity. LAN reachability
  stays opt-in per port (S11).

Naming conventions this plan assumes:

| Thing                | Value                                                               |
| -------------------- | ------------------------------------------------------------------- |
| CLI                  | `scoite`, alias `sc`                                                |
| Instance id          | `scoite-X` (X = launch directory basename, renameable on first run) |
| SSH alias / hostname | `scoite-X`                                                          |
| mDNS name            | `scoite-X.local`                                                    |
| Guest user           | `iosta` (unchanged)                                                 |
| Guest types          | `minimal`, `dev` (default)                                          |
| State root           | `~/.local/state/scoite/<scoite-X>/`                                 |

## Task table

| #   | Step                                                     | Phase         | Status | Depends |
| --- | -------------------------------------------------------- | ------------- | ------ | ------- |
| S0  | Baseline: record what works today                        | 0 groundwork  | done   | —       |
| S1  | Retire/refresh pre-rework sandboxes                      | 0 groundwork  | done   | S0      |
| S2  | Rename `sandvm` → `scoite` (+ `sc` alias)                | 1 rename      | done   | S1      |
| S3  | Collapse four tiers to `minimal` + `dev`                 | 2 guest types | done   | S2      |
| S4  | Paseo daemon in the `dev` guest (PR 3250 overlay)        | 2 guest types | done   | S3      |
| S5  | direnv/devenv auto-provision of `/workspace`             | 2 guest types | done   | S3      |
| S6  | Instance naming `scoite-X` + first-run rename prompt     | 3 identity    | done   | S2      |
| S7  | `scoite rename` on a _running_ instance                  | 3 identity    | done   | S6, S9  |
| S8  | Second NIC: tap on a host bridge (SLIRP kept for egress) | 4 networking  | done   | S2      |
| S9  | mDNS: `scoite-X.local` resolves from abhaile             | 4 networking  | done   | S8      |
| S10 | `scoite list` shows the DNS name                         | 4 networking  | done   | S9      |
| S11 | Expose guest services to the LAN (`:5173`, `:6767`)      | 4 networking  | done   | S9      |
| S12 | omp auth-broker: keep credentials alive + shout when not | 5 propagation | done   | S2      |
| S13 | SSH key/config changes propagate into running guests     | 5 propagation | done   | S12     |
| S14 | Host omp config shared + propagated into guests          | 5 propagation | done   | S12     |
| S15 | Verify nix store sharing (no re-download in guests)      | 5 propagation | done   | S2      |
| S16 | `paseo-desktop` runs on abhaile                          | 5 propagation | done   | —       |
| S17 | SSH lands in `/workspace`                                | 5 propagation | done   | S2      |
| S18 | Per-type default sizing                                  | 6 polish      | done   | S3      |
| S19 | Docs + CLAUDE.md + TODO.md reconciliation                | 6 polish      | done   | S1–S18  |
| S20 | (Optional) guest egress allowlisting — deferred          | 6 polish      | n/a    | S11     |

---

## Phase 0 — groundwork

### S0. Baseline: record what works today

Capture the pre-change state so every later step has something to diff against. No code changes.

- Record `sandvm list` output, the running instances, and their types.
- Build each guest type's runner and note closure sizes:
  `nix build --no-link --print-out-paths .#scoite-guest-{minimal,generic,devenv,workstation}`.
- Note current host services guests depend on: llama-server `127.0.0.1:8080`, omp auth-broker `127.0.0.1:8765`, harmonia
  `127.0.0.1:5000` (guests reach them at `10.0.2.2` via SLIRP).

**Verify:** `nix flake check` passes on a clean tree, all four guest runners build, and the baseline numbers are written
into this file under "S0 result".

### S1. Retire/refresh pre-rework sandboxes

(Was TODO.md item 13.0 + 13.2.) **Done 2026-08-24.** The `legacy` state dirs were already gone; df chose to delete the
two remaining instances and recreate them fresh under the new naming/type scheme rather than migrate their state.

- `main-e57b201a` (minimal, 400M, `/home/df/vaults/main` — the Obsidian vault agent) → removed. Recreate after S2/S3 as
  `scoite-main` (`docs/obsidian.md`).
- `mono-18915ff1` (devenv, 9.9G, guest home alone 4.3G, `/home/df/dev/mono`) → removed. Recreate as `scoite-mono`.
- Before removal, each guest's small agent config dirs (`.claude`, `.codex`, `.config`, `.copilot`, `.paseo`, `.omp`
  where present) were archived to `~/.local/state/scoite-preserve/<old-name>-home.tar.gz` (28K and 272K). Note: the
  guest ships **busybox tar**, so `--ignore-failed-read` is unsupported — list only directories that exist.

**Verified 2026-08-24:** `sandvm rm` reported both removed; `sandvm list` is empty; `~/.local/state/sandvm` is empty;
`/home/df/vaults/main` and `/home/df/dev/mono` (host-side virtiofs workspaces) are untouched.

## Phase 1 — rename

### S2. Rename `sandvm` → `scoite` (+ `sc` alias)

Mechanical but wide. Touch list (grep `sandvm` across the repo first — ~230 hits over 25 files):

- `pkgs/by-name/sandvm/` → `pkgs/by-name/scoite/` (`package.nix`, `completions.fish`); binary `scoite`, plus a `sc`
  symlink in the same derivation (`symlinkJoin` already wraps completions — add `bin/sc`).
- `modules/den/aspects/dev/tools/sandvm.nix` → `scoite.nix` (`den.aspects.dev.tools.scoite`), and its
  `programs.ssh.settings."sandvm-*"` → `"scoite-*"`, `systemd.user.services.sandvm-creds` → `scoite-creds`.
- `modules/den/roles/dev.nix` include `dev.tools.sandvm` → `dev.tools.scoite`.
- `modules/den/hosts/sandvm.nix` → `scoite.nix`; Den host names `sandvm-<tier>` → `scoite-<tier>`; emitted packages
  `sandvm-guest-<tier>` → `scoite-guest-<tier>`.
- `modules/den/aspects/virtualisation/microvm-{guest,host}.nix`: unit names (`sandvm-hostname`, `sandvm-workspace-init`,
  `sandvm-grow-fs`, `sandvm-ssh-config`, …) → `scoite-*`; host state dir `/var/lib/sandvm` → `/var/lib/scoite`
  (activation script must migrate the existing hostkey, not regenerate it — regenerating changes the guests' SSH host
  key and trips `StrictHostKeyChecking`).
- `modules/flake-parts/{devshell,deploy}.nix` references.
- CLI internals: `STATE_ROOT` → `.../scoite`, ssh `config.d/sandvm` → `config.d/scoite`, systemd unit prefix
  `sandvm-<name>` → `scoite-<name>`, `~/.config/sandvm/agent.env` → `~/.config/scoite/agent.env`.
- **No state migration needed** (S1 decision): `~/.local/state/sandvm` is empty. Remove the empty dir, the stale
  `~/.ssh/config.d/sandvm` file and the empty `~/.config/sandvm/` as part of this step.
- Docs: `docs/microvm-sandbox.md` (→ keep filename, retitle), `docs/obsidian.md` (`vault-agent` abbr), `CLAUDE.md`,
  `TODO.md`.
- Keep a **deprecation shim**: `sandvm` as a wrapper that prints a one-line "renamed to scoite" notice and execs
  `scoite` — for a few weeks, then delete (add to S19).

**Verify:**

1. `nix build .#scoite && nix flake check` pass; `grep -rn 'scoite' --exclude-dir=.git .` returns only the shim, docs'
   historical notes, and TODO/MIGRATION history.
2. `nixos-rebuild switch --flake .#abhaile` (the CLI is HM-installed — edits do not reach `$PATH` without it).
3. `scoite list` runs and is empty; `sc list` is identical; `sandvm` prints the deprecation notice and still works.
4. `sc new --workspace /tmp/scoite-probe scoite-probe --ssh` boots a guest, `ssh scoite-probe true` succeeds, and
   `journalctl --user -u scoite-scoite-probe` shows the renamed unit.

---

## Phase 2 — guest types

### S3. Collapse four tiers to `minimal` + `dev`

`modules/den/roles/sandbox.nix` currently nests `minimal ⊂ generic ⊂ devenv ⊂ workstation`. New shape:

- **`minimal`** — unchanged intent: `roles.default` + interactive fish + starship + git + `apps.ai-tools`, internet
  access. "Run this somewhere it can't touch my machine."
- **`dev`** (default) — everything the goal lists: python + node + headless chromium, the full TUI shell/git slice
  (`shell.*` bundles, lazygit, neovim, atuin, eza, yazi, zoxide, delta/difftastic), compilers/nix-ld from today's
  `generic`, `dev.tools.{direnv,devenv,herdr,headless-browser}` from today's `devenv`, plus `dev.lang.{python,nix,go}`
  from `workstation` where cheap. Node is **not** currently in any tier — add `dev.lang.node` (create the aspect if
  absent) or `pkgs.nodejs` directly.
- Delete `generic` and `workstation` tiers; `modules/den/hosts/scoite.nix` maps over the two remaining ones.
- CLI: `--type minimal|dev`, `DEFAULT_TYPE=dev`, usage text, `valid_type()`, completions.
- Existing instances of a removed tier: migrate `generic`/`workstation`/`devenv` → `dev` in `load_config`.

**Verify:**

1. `nix build .#scoite-guest-minimal .#scoite-guest-dev`; record both closure sizes (compare against S0's numbers).
2. `sc new --type dev /tmp/scoite-probe --ssh`, then in-guest: `python3 --version`, `node --version`,
   `chromium --version` (headless), `git --version`, `direnv --version`, `devenv version`, `omp --version` all succeed.
3. `sc new --type minimal /tmp/scoite-probe-min --ssh` boots, has `git` and `curl https://example.com` works, and does
   **not** ship node/chromium.
4. An existing `devenv` instance starts and reports `TYPE=dev` after migration.

### S4. Paseo daemon in the `dev` guest

The daemon comes from getpaseo/paseo's own flake (`nix/package.nix` + `nix/module.nix`); nix-ai-tools only packages
`paseo-desktop`. https://github.com/getpaseo/paseo/pull/3250 is an **open** one-hunk fix to `nix/package.nix` that
copies `node-pty`'s `prebuilds/` into the output — without it terminal panes fail to start in the Nix build. Until it
merges, carry it as an overlay in this repo:

```nix
paseo = prev.paseo.overrideAttrs (old: {
  postInstall = old.postInstall + ''
    cp -r packages/server/node_modules/node-pty/prebuilds \
      "$out/lib/paseo/packages/server/node_modules/node-pty/"
  '';
});
```

- Add `flake-file.inputs.paseo.url = "github:getpaseo/paseo"` in a new `modules/den/aspects/dev/tools/paseo.nix`;
  regenerate with `nix run .#write-flake`.
- Guest side: import paseo's `nix/module.nix` in the `dev` role (or hand-roll a systemd unit if the module drags in host
  assumptions), listening on `:6767`, running as `iosta`, `WorkingDirectory=/workspace`.
- Port 6767 is **not** in `DEFAULT_DEV_PORTS` (3000s/4000s/5000s/5173+/6006/8000s/8080s/9000s) — add it.
- Re-check the PR on each revisit; drop the overlay once merged.

**Verify:**

1. `nix build .#scoite-guest-dev` succeeds with the overlay applied.
2. In a running `dev` guest: `systemctl status paseo` is `active (running)`; a terminal pane opens (the node-pty symptom
   the PR fixes) — check `journalctl -u paseo` for node-pty errors.
3. From abhaile: `curl -sS http://<instance-addr>:6767` (and after S9, `http://scoite-X.local:6767`) returns the
   daemon's response, not a connection refusal.

### S5. direnv/devenv auto-provision of `/workspace`

Largely exists: `scoite-workspace-init` (microvm-guest.nix) pre-builds a project's `devenv.nix`/`flake.nix` at boot and
`/workspace` is direnv-whitelisted. Close the gap: confirm it triggers for `.envrc`-only projects, that failures are
visible (not silently swallowed), and that an interactive SSH session lands in an activated environment.

**Verify:** launch a `dev` sandbox on a project with `devenv.nix` + `.envrc`; `ssh scoite-X` and confirm the project's
tools are on `$PATH` with no manual `direnv allow`; `systemctl status scoite-workspace-init` shows success and
`journalctl -u scoite-workspace-init` shows the build.

---

## Phase 3 — identity

### S6. Instance naming `scoite-X` + first-run rename prompt

Today: `name_for()` = `basename + '-' + sha256[0:8]` (e.g. `mono-18915ff1`). Wanted: `scoite-X` where X is the launch
directory's basename, with the user **prompted to rename on first run**.

- `name_for()` → sanitised basename only; the id is `scoite-<basename>`.
- On `scoite new` (and the bare `scoite <path>` shorthand) prompt: `name this sandbox [scoite-mono]:` — accept empty for
  the default; non-interactive (`--name`, no TTY) skips the prompt.
- **Collisions** (two different folders with the same basename) must be handled explicitly: if `scoite-X` exists with a
  different `WORKSPACE`, refuse and require `--name`. Do not silently reuse — the current hash suffix exists precisely
  to make the folder→name map injective.
- `resolve_name()` keeps accepting both `X` and `scoite-X`.

**Verify:** `mkdir -p /tmp/proj-a && cd /tmp/proj-a && sc new` proposes `scoite-proj-a`, accepts a typed override;
`mkdir -p /tmp/other/proj-a && cd /tmp/other/proj-a && sc new` refuses with a clear "name taken by /tmp/proj-a" message
and succeeds with `--name scoite-proj-a2`.

### S7. `scoite rename` on a running instance

`scoite rename [<name>] <new>` must update, without a reboot:

1. the state dir `~/.local/state/scoite/<old>` → `<new>` (and `WORKSPACE`-relative paths inside `config`),
2. the systemd user unit (`scoite-<old>.service` → `scoite-<new>.service`) — a running unit cannot be renamed in place,
   so either accept a stop/start for the unit only, or keep the unit name stable and decouple it from the display name
   (**preferred**: give each instance an immutable internal id at creation and let the name be a label),
3. `~/.ssh/config.d/scoite` block, so `ssh scoite-<new>` works immediately,
4. the guest's hostname (`hostnamectl set-hostname` over ssh) and its mDNS publication (restart avahi in the guest), so
   `scoite-<new>.local` resolves and `scoite-<old>.local` stops resolving.

**Verify:** with an instance running and a dev server on `:5173`: `sc rename scoite-old scoite-new`; then
`ssh scoite-new true`, `getent hosts scoite-new.local`, `curl http://scoite-new.local:5173` all succeed and
`getent hosts scoite-old.local` fails — with no interruption to the guest's running processes.

---

## Phase 4 — networking, DNS, exposure

### S8. Second NIC: tap on a host bridge (SLIRP kept for egress)

**Design decision (confirmed by df 2026-08-24).** Today the guest has one SLIRP (`type = "user"`) NIC: zero host setup,
host-only inbound via qemu `hostfwd`, and — load-bearing — the host reachable at `10.0.2.2` for llama-server `:8080`,
the omp auth-broker `:8765`, and harmonia `:5000`. Replacing SLIRP wholesale breaks all three. Instead **add** a second
interface: a `tap` on a host-managed bridge (`scoitebr0`, NAT'd, dnsmasq-served, like libvirt's `virbr0`), giving each
guest a real routable address that the host — and, after S11, the LAN — can reach, while the default route stays on
SLIRP so nothing existing changes.

- Host: `modules/den/aspects/virtualisation/microvm-host.nix` gains the bridge, its address, NAT, and persistent
  df-owned tap devices (or qemu's bridge helper with `/etc/qemu/bridge.conf`) — tap creation needs root, the CLI must
  not.
- Guest: second `microvm.interfaces` entry; systemd-networkd DHCP on it with `UseRoutes=no`/high metric so egress keeps
  flowing through SLIRP.
- Watch: `networking.firewall.enable = false` in the guest was justified by "SLIRP gives exactly one inbound path". With
  a bridge that reasoning no longer holds — re-enable a guest firewall or accept it explicitly and write down why.
- Tailscale gotcha (memory, abhaile): a tailscale-routed subnet can hijack local VM subnets — pick a bridge subnet that
  does not collide and check `ip rule`/`ip route` after bringing it up.

**Verify:** in a running guest, `ip -br addr` shows both NICs with addresses; `ip route` default is still the SLIRP
gateway; `curl http://10.0.2.2:8080/v1/models` still works (llama-server); from abhaile `ping <guest-bridge-ip>` and
`ssh iosta@<guest-bridge-ip>` succeed; `sc creds` still refreshes a running guest.

### S9. mDNS: `scoite-X.local` resolves from abhaile

- Guest: enable avahi (publish `.local`, hostname from the `INSTANCE` credential — it was deliberately removed from
  `roles.default` in 2026-07-14 as "mDNS behind SLIRP reaches nothing"; with S8's bridge it does reach). Keep it out of
  `minimal` if it costs boot time, or accept it in both — record the measurement.
- Host: abhaile already runs avahi (`core.network.avahi` via `roles.workstation`) — confirm `nssmdns4` is on in
  `/etc/nsswitch.conf`, add it if not.
- Guest hostname must be the instance name (`scoite-X`), which arrives as the `INSTANCE` boot credential — the system
  closure must stay name-free (the shared-closure invariant).

**Verify:** `getent hosts scoite-X.local` on abhaile returns the guest's bridge address; `ssh scoite-X.local true`
works; `avahi-browse -at | grep scoite` lists the guest; two simultaneous guests resolve to different addresses.

### S10. `scoite list` shows the DNS name

Add a `DNS` column (`scoite-X.local`) beside `ADDRESS`. Keep the loopback forward address too — it stays the zero-config
path for host-only access.

**Verify:** `sc list` prints NAME / TYPE / STATUS / ADDRESS / DNS / ON-DISK / WORKSPACE, and the DNS value of a running
instance resolves (`getent hosts $(sc list | awk ...)`); a stopped instance shows the name without claiming it resolves.

### S11. Expose guest services to the LAN

(Was TODO.md item 7.5.) With S8's NAT bridge, guests are reachable from abhaile only. To reach a Vite app (`:5173`) or
the paseo daemon (`:6767`) from another device:

- Either DNAT specific ports from abhaile's LAN address to the guest (`scoite expose --lan <port>`, an nftables rule the
  CLI asks a small privileged helper to install — the CLI itself stays unprivileged), plus an avahi CNAME/alias so
  `scoite-X.local` resolves LAN-wide (or reflect mDNS across the bridge with `services.avahi.reflector`),
- Or bridge the tap onto the physical LAN (`br0` over the NIC) so guests take LAN addresses directly and mDNS crosses
  natively — simpler routing, more exposure, and it changes abhaile's own networking.
- Whichever: the default must stay **not exposed**; exposure is opt-in per port, per instance, and visible in `sc list`.
  Also decide egress policy here (TODO item 7.6, smolvm-style allowlisting) or explicitly defer it.

**Verify:** from a second LAN device (phone), `http://scoite-X.local:5173` loads the guest's Vite app and
`http://scoite-X.local:6767` reaches paseo; after `sc unexpose scoite-X 5173` the same URL is refused; a _non_-exposed
port is refused throughout.

---

## Phase 5 — host ↔ guest propagation

### S12. omp auth-broker: keep credentials alive + shout when they are not

(Was TODO.md item 13.3.) The broker refreshes provider credentials on the host and guests query it per request, so
guests never hold a token. Two failure modes remain: a rotated **bearer** token (fixed by `sc creds`, already on a
10-minute timer + every `ssh`), and a definitive `invalid_grant` refresh failure, after which the broker sets
`disabled_cause` and **every** consumer silently loses omp (happened 2026-08-23, invisible outside the journal; abhaile
also had a stale duplicate anthropic row being retried every 60s).

- Add a `systemd --user` timer polling
  `curl -H "Authorization: Bearer $(cat ~/.omp/auth-broker.token)" http://127.0.0.1:8765/v1/credentials/disabled` plus
  the snapshot (to catch duplicate/stale rows), failing the unit and raising a desktop notification when the list is
  non-empty. No notification infrastructure exists in this repo yet — add `libnotify` and pick a mechanism as part of
  this step.
- Confirm the goal's "various providers" (Anthropic, OpenRouter, …) each work end to end from a guest.

**Verify:** with a deliberately disabled credential (or a synthetic non-empty `/v1/credentials/disabled` response) the
timer fails loudly and a notification appears within one interval; after `omp auth-broker login anthropic` the alert
clears without a broker restart; from inside a guest an `omp` print-mode round trip against a cloud provider succeeds,
and a second provider (OpenRouter) does too.

### S13. SSH key/config changes propagate into running guests

Today `SSH_CONF` (df's `~/.ssh/sshconfig.local` + the _public_ halves of the keys it names) is a launch-time fw_cfg
credential; auth itself is forwarded-agent. So a newly added host alias or key requires a stop/start. Make it behave
like `sc creds`: re-push `SSH_CONF` into a running guest and have `scoite-ssh-config` re-unpack it.

**Verify:** with a guest running, add a new `Host` block + key to the host's `sshconfig.local`, run `sc creds <name>`
(or the dedicated subcommand), open a **new** guest shell and confirm the alias resolves (`ssh -G <alias>`),
`ssh-add -l` lists the host agent's keys, and `ssh -T git@github.com` authenticates as df.

### S14. Host omp config shared + propagated into guests

The goal wants the host's oh-my-pi configuration itself (not just credentials) available in every guest. Today the guest
only seeds `~/.omp/agent/models.yml` (pointing the `local` provider at `http://10.0.2.2:8080/v1`) and reads the broker.
Decide what is safe to ship (settings/agents/prompts — **not** tokens), deliver it by the same fw_cfg credential
mechanism, and re-push it on change alongside S13.

- Also: the guest's `models.yml` model ids/context sizes are hand-synced with `llm.nix`'s router presets — generate them
  from one source instead, or add a check that fails when they drift.

**Verify:** change a setting in the host's omp config, propagate, and confirm a new guest shell's `omp` reflects it;
confirm no credential material appears in the guest's `~/.omp` or in `/nix/store`; `omp` against the host's llama-server
(`local` provider) still answers.

### S15. Verify nix store sharing

Already built: the host store is 9p-mounted read-only in the guest, plus harmonia on `10.0.2.2:5000` as an unsigned
binary cache. This step is a **measurement**, not new code: prove a package already on abhaile is not re-downloaded.

**Verify:** pick a store path present on the host but not in the guest overlay; `nix build` it in the guest and confirm
from `journalctl`/`nix build -v` that it came from the host cache (substituted from `http://10.0.2.2:5000`) or was
already visible on the ro-store mount — no fetch from cache.nixos.org. Record the timing.

### S16. `paseo-desktop` runs on abhaile

`inputs.nix-ai-tools.packages.…paseo-desktop` (0.4.0) is already in `apps.ai-tools`
(`modules/den/aspects/apps/ai-tools.nix`) → `roles`. Likely already satisfied; confirm it actually launches on a
Wayland/GNOME session rather than only being installed.

**Verify:** `paseo-desktop --version` and a GUI launch on abhaile; it can talk to a guest's paseo daemon (S4) over
`scoite-X.local:6767` once S9/S11 land.

### S17. SSH lands in `/workspace`

`microvm-guest.nix` already `cd`s interactive fish sessions into `/workspace` when `$PWD` is `$HOME`. Confirm it
survives the rename and holds for `ssh scoite-X` and for `code --remote`/`sc ssh`.

**Verify:** `ssh scoite-X pwd` (interactive shell path) and an interactive `sc ssh` session both report `/workspace`.

### S18. Per-type default sizing

(Was TODO.md item 13.4.) All types share `--cpu 4 --mem 32768 --disk 32768 --home-disk 16384`. `minimal` should want
much less. Measure actual usage of a running instance of each type and set per-type defaults.

**Verify:** record measured peak RSS/disk per type; `sc new --type minimal` and `--type dev` pick the new defaults, and
a `dev` sandbox still builds a real project without hitting a disk/RAM ceiling.

### S19. Docs + CLAUDE.md + TODO.md reconciliation

- Rewrite `docs/microvm-sandbox.md` around `scoite`, the two types, the bridge/mDNS model, and the new subcommands.
- Update `CLAUDE.md`'s sandbox section + gotchas (state paths, `sc`, DNS names, exposure, credential propagation).
- Fold the migrated TODO.md items (7.5, 7.6, 13.0–13.4) into their Done history and point item 13 at this file.
- Update `docs/obsidian.md` (vault agent = `sc ~/vaults/main`, abbr).
- Drop the `scoite` deprecation shim.

**Verify:** `nix flake check` and `nix fmt` clean; `grep -rn 'scoite' --exclude-dir=.git .` returns only historical
notes in TODO/MIGRATION; a cold read of `docs/microvm-sandbox.md` describes the shipped system.

---

## Results log

<!-- Append per-step results here as steps are verified: date, command output summary, decisions taken. -->

### S0 result — 2026-08-24

Baseline on a tree at `b98f6f4` + staged `dev/apps.nix` (`pkgs.uv`) and the new `GOAL.md`/`TASKS.md`.

- `nix build --no-link .#scoite-guest-{minimal,generic,devenv,workstation}` — all four build (exit 0).
- Guest system closures (`nix path-info -S` on each `nixosConfigurations.scoite-<tier>.…toplevel`):

  | tier        | closure  |
  | ----------- | -------- |
  | minimal     | 3.7 GiB  |
  | generic     | 7.4 GiB  |
  | devenv      | 9.8 GiB  |
  | workstation | 10.4 GiB |

  (2026-08-22's writeup recorded 3.0 / 6.8 / 9.2 / 9.7 GiB — everything has grown ~0.7 GiB with nixpkgs drift.)

- `scoite list` — two instances, both already on the per-instance-address scheme, no `legacy` rows:

  | name          | type    | status  | address       | on-disk | workspace            |
  | ------------- | ------- | ------- | ------------- | ------- | -------------------- |
  | main-e57b201a | minimal | running | 127.153.250.1 | 400M    | /home/df/vaults/main |
  | mono-18915ff1 | devenv  | running | 127.212.107.1 | 9.9G    | /home/df/dev/mono    |

- Host services guests depend on (SLIRP `10.0.2.2`): llama-server `:8080`, omp auth-broker `:8765` (`active`), harmonia
  `:5000`. abhaile's avahi daemon is `active` (needed by S9).
- `nix flake check`: see below.

### S2 result — 2026-08-24

Renamed across 25 files (~230 hits). Files moved: `pkgs/by-name/sandvm/` → `pkgs/by-name/scoite/`,
`modules/den/aspects/dev/tools/sandvm.nix` → `scoite.nix`, `modules/den/hosts/sandvm.nix` → `scoite.nix`. Den guest
hosts are now `scoite-{minimal,generic,devenv,workstation}` emitting `packages.scoite-guest-<tier>`.

Beyond the mechanical rename:

- **Three entry points** from one derivation (`symlinkJoin.postBuild`): `scoite`, `sc` (symlink), and `sandvm` (a shim
  that prints "renamed to 'scoite'" on stderr and execs `scoite`). Fish completions are installed for both `scoite` and
  `sc` (`-c scoite` → `-c sc` via sed at build time). The shim is scheduled for deletion in S19.
- **deploy-rs bug found and fixed** (`modules/flake-parts/deploy.nix`): the node list did
  `removeAttrs config.flake.nixosConfigurations [ "sandvm" ]`, but the guest hosts have always been named
  `sandvm-<tier>` — so that filter matched nothing and every sandbox tier was being turned into a deploy node _and_ a
  `deployChecks` target (four extra guest toplevels re-evaluated on every `nix flake check`). Now a prefix filter:
  `lib.filterAttrs (name: _: !lib.hasPrefix "scoite-" name)`. `nix flake check` is correspondingly cheaper.
- **Host key migrated, not regenerated** (`microvm-host.nix`): the activation script now moves `/var/lib/sandvm` →
  `/var/lib/scoite` when present. Instances reuse loopback addresses (`127.x.y.1`), so a fresh key would have collided
  with existing `~/.ssh/known_hosts` entries. Verified: the July 12 key survived the move.
- Stale host paths removed by hand (all were empty): `~/.local/state/sandvm`, `~/.ssh/config.d/sandvm`,
  `~/.config/sandvm`. No migration code was added to the CLI — S1 left nothing to migrate.
- `GOAL.md` and `TODO.md` are deliberately **not** renamed: they record what was said/done at the time.

**Verified 2026-08-24:**

1. `nix build .#scoite` + all four `.#scoite-guest-*` runners build; `nix fmt` clean; `nix flake check` → "all checks
   passed!".
2. `sudo nixos-rebuild switch --flake .#abhaile` succeeded — the generation diff shows `sandvm`, `sandvm-creds.service`,
   `sandvm-creds.timer`, `sandvm-fish-completions` removed and the `scoite` equivalents added; closure delta +38 KiB.
3. `scoite`, `sc` and `sandvm` all on `$PATH`; `sc list` == `scoite list`; `sandvm list` prints the deprecation notice
   first.
4. `sc new --workspace /tmp/scoite-probe probe` booted a guest as unit `scoite-probe.service` (`127.187.156.1`, type
   `devenv`), and `ssh scoite-probe` returned `probe` / `iosta`. The probe is left running as the S3 tier-migration test
   case.
5. `grep -rn sandvm` over the repo returns only: `GOAL.md`/`TODO.md`/`TASKS.md` history, the CLAUDE.md in-flight note,
   the deploy.nix comment explaining the old filter bug, and the shim itself.

### S3 result — 2026-08-24

Four tiers → two. `modules/den/roles/sandbox.nix` now defines `minimal` and `dev` (`dev` includes `minimal`);
`modules/den/hosts/scoite.nix` maps over the two, emitting `packages.scoite-guest-{minimal,dev}`.

- **New aspect `dev.lang.node`** (`modules/den/aspects/dev/lang/node.nix`): `nodejs` 24.18.1 (npm/npx ride inside it)
  plus `pnpm` and `bun`. Node was in no tier before. corepack is deliberately not installed — it collides with the
  nodejs derivation over the same `corepack` binary.
- `dev` = old `generic` ∪ `devenv` ∪ `workstation` plus node: compilers/`nix-ld`, full TUI shell + git stack,
  devenv/direnv, herdr (+autostart), headless chromium/playwright, `dev.lang.{node,python,nix,go}`, trippy.
- **In-place type migration** in the CLI's `load_config`: an existing sandbox with `TYPE=generic|devenv|workstation` is
  rewritten to `dev` (a superset of all three) with a one-line notice, keeping its home and store overlay.
- Closures: `minimal` **3.7 GiB** (unchanged), `dev` **10.5 GiB** (old `workstation` was 10.4, `devenv` 9.8 — the delta
  is node/pnpm/bun).

**Verified 2026-08-24:**

1. `nix build .#scoite-guest-{minimal,dev}` both build; `nix fmt` clean; `nix flake check` → "all checks passed!";
   `nixos-rebuild switch` applied.
2. Migration: the S2 probe (`TYPE=devenv`) restarted straight into `TYPE=dev` — `sc list` shows `dev`, its config file
   was rewritten, and its persistent home/overlay survived.
3. In the `dev` guest: `python3` 3.14.6, `node` v24.18.1, `npm` 11.16.0, `pnpm` 11.20.0, `bun` 1.3.13, `git` 2.55.0,
   `direnv` 2.37.1, `chromium`/`headless-chromium` 151.0.7922.108, `herdr` 0.8.2, `omp` 17.4.2, `devenv` 2.2.1.
4. In a fresh `--type minimal` guest (`scoite-probemin`): `git` 2.55.0, `omp` and `claude` present, `node` **absent**,
   `chromium` **absent**, and `curl https://example.com` → 200 (internet access works).

### S4 result — 2026-08-24

New aspect `dev.tools.paseo` (`modules/den/aspects/dev/tools/paseo.nix`), included by `roles.sandbox.dev`. New flake
input `paseo` (`github:getpaseo/paseo`, `inputs.nixpkgs.follows = "nixpkgs-unstable"`); `flake.nix` regenerated with
`nix run .#write-flake`. The daemon (0.5.2) comes from upstream's own `nix/package.nix` + `nix/module.nix` —
nix-ai-tools packages only `paseo-desktop`.

Configuration decisions, each with a reason worth keeping:

- **PR 3250 carried as an `overrideAttrs` postInstall** — copies `node-pty/prebuilds` into the traced output. Delete the
  override when the PR merges (re-check on every `nix flake update`).
- `user = "iosta"` → `PASEO_HOME=/home/iosta/.paseo` on the persistent home volume, and the module's
  `inheritUserEnvironment` (default true for a non-`paseo` user) gives spawned agents iosta's PATH.
- `listenAddress = "0.0.0.0"` — the guest runs no firewall by design, so qemu's forwards _are_ the ACL.
- `hostnames = [ ".local" ]` — the daemon has DNS-rebinding protection and rejects unknown `Host:` headers; `.local` is
  what a browser will send once S9's mDNS names exist. Verified: `Host: probe.local` is accepted.
- `relay.enable = false` — upstream defaults to dialling `app.paseo.sh` so the mobile app can reach the daemon from
  anywhere. That is precisely the outbound channel a sandbox should not have.
- `settings.features.{dictation,voiceMode}.enabled = false` — **found during verification**: both default to a `local`
  speech provider and the daemon immediately background-downloads parakeet-tdt-0.6b + kokoro (hundreds of MB) into
  `$PASEO_HOME`, i.e. into _every_ sandbox's home volume, for a feature a headless guest cannot use.
- Unit ordering: `after`/`requires` `scoite-home-perms.service` + `RequiresMountsFor=/home/iosta`, so preStart never
  writes `config.json` into a still-root-owned mountpoint.
- CLI: **6767 added to `DEFAULT_DEV_PORTS`**, so every launch forwards the daemon without `--port`.

**Verified 2026-08-24** (guest `scoite-probe`, `dev` tier, closure 10.7 GiB):

1. `nix build .#scoite-guest-dev` succeeds with the override applied; `nix fmt` clean.
2. `systemctl is-active paseo` → `active`; the daemon logs `Server listening on http://0.0.0.0:6767`,
   `daemonVersion 0.5.2`; with voice disabled, `journalctl -u paseo | grep -c "model download"` → **0**.
3. **node-pty works** — the symptom PR 3250 fixes: `prebuilds/linux-x64/pty.node` is present in the package, and
   `node -e 'require("node-pty").spawn("/bin/sh", ["-c","echo PTY_OK"])'` inside the guest printed `PTY_OK`.
4. From abhaile: `curl http://127.187.156.1:6767/api/health` → `{"status":"ok",…}`, both with the default `Host:` and
   with `Host: probe.local`.

**Carried forward to S11:** the daemon runs with `authRequired: false` (no password set). That is fine while the only
path in is a host-loopback forward, but LAN exposure must set a password (`paseo daemon set-password`, or the
`daemon.auth.password` bcrypt hash via `settings`) before port 6767 is opened to anything.

### S5 result — 2026-08-24

`scoite-workspace-init` (in `virtualisation/microvm-guest.nix`) reworked rather than merely confirmed — the two gaps the
step called out were both real:

- **`.envrc`-only projects were not handled.** The unit only knew `devenv.nix` and `flake.nix`. It now tries
  `direnv exec /workspace true` first, because `.envrc` is the entry point the shell actually uses and it can point
  anywhere (`use flake`, `use devenv`, `layout python`, hand-written PATH); building it also pre-populates direnv's own
  cache, so the first shell in `/workspace` is instant. devenv.nix/flake.nix stay as fallbacks. `pkgs.direnv` added to
  the unit's `path`.
- **Failures were swallowed** (`|| echo "… (non-fatal)"`, unit still green). They now propagate: nothing orders after
  this unit, so a failure costs the guest nothing and shows up in `systemctl status scoite-workspace-init`.
- Added `after = [ "home-manager-iosta.service" ]`: direnv's whitelist (`whitelist.prefix = ["/workspace"]`, from
  `roles.sandbox.dev`) is a home-manager file, and without the ordering the pre-build could run before
  `~/.config/direnv/direnv.toml` exists — direnv would then block the very `.envrc` it was launched to evaluate.

**Verified 2026-08-24** with a purpose-built project `/tmp/scoite-devtest` (`.envrc` = `use flake`; flake devShell with
`hello`, `cowsay` and `SCOITE_S5_MARKER`), launched as sandbox `scoite-devtest`:

1. `systemctl is-active scoite-workspace-init` → `active`, `Result=success`; the journal shows the devShell being built
   and `direnv: nix-direnv: Renewed cache`. No manual `direnv allow` anywhere.
2. In an interactive session, `cd /workspace` activates the environment: `SCOITE_S5_MARKER=workspace-env-active` and
   `hello` resolves to the devShell's store path.

**Carried forward:** the pre-build fetched `cowsay` from `cache.nixos.org`, not from abhaile's harmonia at
`10.0.2.2:5000` — worth understanding in S15 (substituter order / priority), since the whole point of the local cache is
that guests don't re-download what the host already has.

### S6 result — 2026-08-25

An instance is now `scoite-<name>` in every place it is visible — state directory, ssh alias, systemd unit and the
guest's own hostname are all the same string. The `basename-<8 hex of the path hash>` scheme is gone.

CLI changes (`pkgs/by-name/scoite/package.nix`):

- `name_for <path>` → `scoite-<basename>`; `sanitise_name` lowercases and reduces to `[a-z0-9-]` (the name becomes a DNS
  label in S9, so it has to be one); `prefixed` applies `scoite-` exactly once.
- `resolve_name` accepts either spelling and prefers an existing sandbox: `sc ssh mono` and `sc ssh scoite-mono` both
  work, and pre-S6 instances (state dirs without the prefix) keep resolving.
- **First-run prompt**: `scoite new` in a folder proposes `scoite-<folder>` and lets you edit it
  (`name this sandbox [scoite-proj-a]:`). `--name` (new flag, with completion) skips it, and a non-interactive caller
  silently takes the default.
- **Collisions are refused, never resolved silently**: a second folder with the same basename gets
  `'scoite-proj-a' is taken by /tmp/proj-a - pick another with: scoite new --name <name> …`; the _same_ folder gets
  `already exists for this folder (scoite start …)`.
- **`ID` in the per-instance config** — the systemd unit name, fixed at creation, deliberately decoupled from the
  display name because a running unit cannot be renamed. `unit_of` reads it (falling back to the directory name for
  pre-S6 instances). This is what makes S7's live rename possible.

Bug caught in verification: the prompt runs inside `name=$(prompt_name …)`, so its stdout is a pipe and the original
`[ -t 1 ]` guard was always false — the prompt never appeared in a real terminal. Now guarded on stdin+stderr
(`[ -t 0 ] && [ -t 2 ]`), with the prompt written to stderr.

**Verified 2026-08-25:**

1. `sc new --workspace /tmp/proj-a` → instance `scoite-proj-a`, unit `scoite-proj-a.service`, and `hostname` inside the
   guest is `scoite-proj-a`.
2. Collision: `/tmp/other/proj-a` refused with the message above; `--name proj-a2` then succeeded as `scoite-proj-a2`.
3. Prompt driven over a real pty: `name this sandbox [scoite-proj-c]:` with `My Custom Box` typed produced
   `scoite-my-custom-box` (sanitised) and unit `scoite-my-custom-box.service`.
4. `sc ssh proj-a`, `sc ssh scoite-proj-a` and a pre-S6 instance (`devtest`) all resolved; `~/.ssh/config.d/scoite`
   holds one `Host scoite-<name>` block per instance.
5. Test instances removed; two clean ones recreated for the networking steps: `scoite-devtest` (dev, the S5 flake
   project) and `scoite-mintest` (minimal).

### S8 result — 2026-08-25

Guests now have **two** NICs: `eth0` = qemu SLIRP (unchanged, keeps the default route and the 10.0.2.2 path to abhaile's
loopback services), `eth1` = a tap on the new host bridge `scoitebr0` (10.77.0.0/24). Nothing that worked before goes
through the new path.

Host (`virtualisation/microvm-host.nix`):

- `scoite-bridge.service` — plain iproute2, not `networking.bridges`/`systemd.network`: abhaile's networking is
  NetworkManager's and this bridge wants to be invisible to it (`networkmanager.unmanaged`). It carries no uplink.
- `dnsmasq-scoite.service` — DHCP only, `--port=0` so it can never race systemd-resolved for :53. Leases in
  `/var/lib/scoite/dnsmasq.leases`.
- `networking.firewall.trustedInterfaces = [ "scoitebr0" ]`; `virtualisation.libvirtd.allowedBridges` extended so qemu's
  setuid `qemu-bridge-helper` will attach an unprivileged guest's tap (the wrapper and `/etc/qemu/bridge.conf` both come
  from the libvirtd module — hence an assertion that libvirtd is enabled).
- Subnet 10.77.0.0/24, chosen against libvirt's 192.168.122.0/24, the LAN's 192.168.178.0/24, SLIRP's 10.0.2.0/24 and
  tailscale's 100.64/10.

Guest (`virtualisation/microvm-guest.nix`): second interface `type = "bridge"`, `usePredictableInterfaceNames = false`
(eth0/eth1 follow interface _order_, which is the only thing a shared closure can rely on), one `.network` file each,
and `services.resolved` with `MulticastDNS` on eth1. The bridge NIC takes an address and nothing else —
`UseRoutes/UseDNS/UseNTP/UseHostname = false` — so SLIRP stays the way out.

Three failures found and fixed during verification, each worth remembering:

1. **Tailscale hijacked the subnet.** `ip route get 10.77.0.106` → `dev tailscale0 table 52`: with `--accept-routes`,
   tailscale's rule at priority 5270 outranks the main table and table 52 holds a route for 10.77.0.0/24. DHCP kept
   working (it is L2) so the bridge looked healthy while every ping/ssh/curl black-holed. Fixed with
   `ip rule add to 10.77.0.0/24 lookup main priority 5000` in the bridge unit — the same failure libvirt's
   192.168.122.0/24 has on this host.
2. **Restarting the bridge unit orphaned a live guest.** The original `preStop` deleted the bridge, which silently
   detaches every enslaved tap; the sandboxes stayed up (SLIRP is a separate NIC) but were unreachable on the bridge
   until restarted. `preStop` now only removes the ip rule — the idle bridge costs nothing.
3. **Both guests got the same DHCP lease** (10.77.0.106 each). networkd's default client identifier is a DUID derived
   from `/etc/machine-id`, and every guest of a type shares one system closure and therefore one machine-id, so dnsmasq
   correctly treated them as the same client. Fixed with `dhcpV4Config.ClientIdentifier = "mac"`; the MAC itself is
   per-instance, generated by the CLI's new `mac_for` (`02:5c:` + 4 bytes of the name's sha256) and passed as
   `MICROVM_BR_MAC` — it feeds the runner cache key, so it never touches the system closure.

**Verified 2026-08-25:** both NICs configured in-guest; default route still `10.0.2.2` via eth0; from the guest
`10.0.2.2:8080` (llama-server) → 200, `10.0.2.2:8765` (omp broker) → 401 (reachable, auth required),
`https://example.com` → 200; from abhaile `ping 10.77.0.106` → 0% loss and `ssh iosta@10.77.0.106` → ok;
`scoite-devtest` and `scoite-mintest` hold distinct MACs and distinct leases (.106 / .221); `sc creds --all` still
refreshes both.

### S9 result — 2026-08-25

`scoite-<name>.local` resolves on abhaile. The guest side needed no avahi: `services.resolved` with
`MulticastDNS = true` on the bridge NIC (added in S8) publishes the hostname, which the `INSTANCE` boot credential has
already set to the instance name — so the closure stays name-free.

Host side, `core.network.avahi`: `nssmdns4`/`nssmdns6` were **off**, so `/etc/nsswitch.conf` had no mdns entry and glibc
could not resolve any `.local` name — `avahi-resolve` worked while `getent`, ssh, curl and browsers did not. Also turned
on `publish.{enable,addresses,workstation}` so the reverse direction (a guest resolving `abhaile.local`) works. `hosts:`
is now `mymachines mdns_minimal [NOTFOUND=return] files myhostname dns`.

**Verified 2026-08-25:** `avahi-resolve -4 -n scoite-devtest.local` → 10.77.0.106; `getent ahostsv4` agrees;
`ssh iosta@scoite-devtest.local` → ok; `curl http://scoite-devtest.local:6767/api/health` → `{"status":"ok",…}` (the
paseo daemon accepting the `.local` Host header, as configured in S4); `scoite-mintest.local` resolves to its own
address. Note: bare `getent hosts <name>.local` answers with the IPv6 link-local address first — clients that try both
(ssh, curl) are unaffected; use `getent ahostsv4` when the v4 address is what you want.

### S10 result — 2026-08-25

`scoite list` now prints `NAME TYPE STATUS DNS IP FORWARD ON-DISK WORKSPACE`:

- **DNS** — `<name>.local` while the instance is running, `-` when stopped (a stopped guest publishes nothing, and
  printing a name that does not resolve would be worse than printing none).
- **IP** — the guest's address on the scoitebr0 bridge, resolved via mDNS (`getent ahostsv4`, the same path ssh and a
  browser take, so an answer proves the DNS column works) with the host's dnsmasq lease file as fallback for the gap
  between DHCP and the first mDNS announcement.
- **FORWARD** — the private 127.x.y.1 the guest's ports are also forwarded to; unchanged, still the zero-config
  host-only path.

**Verified 2026-08-25:** running instances show `scoite-devtest.local` / `10.77.0.106` and `scoite-mintest.local` /
`10.77.0.221`; a stopped instance shows `-` for both and keeps its FORWARD address.

### S7 result — 2026-08-25

`scoite rename [<name>] <new>` (alias `mv`) renames a **running** sandbox with no restart and no interruption to what is
running inside it.

What moves: the state directory (renaming it under a live qemu is safe — cwd and open files follow the inode, and every
path the CLI re-derives lives inside the directory that moved), the `~/.ssh/config.d/scoite` alias block, the guest's
hostname and therefore its mDNS `<name>.local`, and `WORKSPACE` when the project folder lived inside the state
directory. What deliberately stays: the systemd unit (config's `ID`, from S6 — a running unit cannot be renamed and
killing it would kill the guest), the loopback forward address, the SSH host key, and the MAC/DHCP lease.

Two failures found in verification, both now encoded in the code's comments:

1. `hostnamectl hostname '<new>'` → _"Could not set static hostname: /etc/hostname is in a read-only filesystem"_.
2. `hostnamectl hostname --transient` → _"static hostname is already set, so the specified transient hostname will not
   be used"_ — systemd ignores a transient name whenever a static one exists, and the guest's static name is `sandbox`,
   baked into the shared closure.

So the rename does what boot does: a raw `sudo hostname <new>`, **plus** `sudo systemctl restart systemd-resolved` —
resolved caches the name it announces over mDNS and a `sethostname()` behind its back sends it no dbus signal, so
without the restart the guest keeps answering to its old name.

**Verified 2026-08-25** on a running `dev` guest serving `python3 -m http.server 5173`:
`curl http://scoite-devbox.local:5173` → 200 before, `sc rename devbox devtest`, then
`curl http://scoite-devtest.local:5173` → 200 with **the same server pid (15200)**; `hostname` in the guest reports
`scoite-devtest`; `ssh scoite-devtest` works immediately; the old `scoite-devbox.local` stopped resolving after ~56 s
(the host's mDNS cache TTL — the answer is gone, not the record).

### S11 result — 2026-08-25

`scoite expose [<name>] --lan [--lan-port <n>] <port>` opens exactly one port, for one sandbox, to the rest of the
network; `scoite unexpose --lan <port>` closes it. Nothing is exposed by default and nothing is exposed implicitly.

How it works:

- **Root-side helper `scoite-lan` (add|del|list)**, installed by `virtualisation/microvm-host.nix`. The CLI stays
  unprivileged and calls `sudo scoite-lan …` (df has passwordless sudo via `core.security`'s sudo-rs). iptables, not
  nft: abhaile's firewall, libvirt and tailscale all live in the iptables world here.
- A DNAT in chain `SCOITE_LAN` on the **default-route interface** (recomputed per call, so it survives a wifi/ethernet
  switch) to the guest's bridge address, tagged with an iptables comment (`scoite:<lanport>:<ip>:<port>`) so rules can
  be found and deleted precisely.
- A **MASQUERADE** in `SCOITE_LAN_POST` for traffic entering the bridge. Not optional: a guest's default route is qemu's
  SLIRP gateway, so without SNAT it answers a LAN client down SLIRP and the connection hangs.
- Per-instance state `LAN_PORTS=<guest>:<lan>,…` in the sandbox's config: shown in `scoite list`'s new **LAN** column,
  torn down on `stop`/`rm`, and re-applied automatically after the guest boots on `start`.
- **Collisions refused**: every exposure lands on the one LAN address, so a second sandbox asking for the same LAN port
  is told to pick another with `--lan-port`.
- **Warning on :6767** — paseo ships with `authRequired: false` (S4), so exposing it hands the agent to anyone who can
  reach the port.
- The URL is abhaile's own name (`http://abhaile.local:<port>`), not the guest's. A guest's `<name>.local` is published
  on the sandbox bridge only, and abhaile's LAN is **wifi**, where bridging a guest's MAC onto the LAN is not possible
  (802.11 has no 4-address mode here). Reaching guests by their own name from the LAN would need a routed subnet on the
  LAN router — out of scope, and recorded here rather than half-built.

**The blocker this step uncovered — abhaile could not be reached from its own LAN at all.** abhaile _uses_ eachtrach as
a tailscale exit node (a runtime pref; the repo only ever said it does not _advertise_ one), with
`ExitNodeAllowLANAccess: false`. Tailscale then routes everything non-tailnet into the tunnel, **including
directly-connected subnets**: `ip route get 192.168.178.31` → `dev tailscale0 table 52`. Inbound LAN connections
therefore arrived on wifi and had their replies sent down the tunnel — invisible unless you look, and fatal to any
service abhaile offers its LAN, not just sandboxes. Fixed declaratively in `services/tailscale.nix` with
`--exit-node-allow-lan-access` (a no-op when no exit node is selected) plus a one-off
`tailscale set --exit-node-allow-lan-access=true`; `ip route get 192.168.178.31` now says `dev wlp8s0`.

**Verified 2026-08-25** with a real external client — a network namespace on a veth, routing to abhaile like any other
off-host machine, with an equivalent DNAT on that interface:

1. Before the tailscale fix: DNAT counters incremented and the guest's own log showed `GET / 200`, but the client never
   received a reply — exactly the return-path failure described above.
2. After it: `http://<host>:5173` → **200** (the guest's dev server) and `http://<host>:6767/api/health` →
   `{"status":"ok",…}` (the paseo daemon), both through the DNAT.
3. Lifecycle: `sc expose devtest --lan 5173` → `sc list` shows `LAN 5173:5173`; `sc stop` removes the rule
   (`scoite-lan list` empty); `sc start` re-installs it; `sc unexpose --lan 5173` removes it and clears `LAN_PORTS`.
4. Test scaffolding (netns, veth, extra rules) removed; both sandboxes are back to nothing exposed.

**Egress allowlisting (old TODO item 7.6) is explicitly deferred** — see S20. Guest egress still goes out through SLIRP
unrestricted; the bridge adds no new outbound path (no default route, no NAT to the LAN), so S11 does not widen egress
at all.

## S20 — (Optional) guest egress allowlisting (deferred 2026-08-25)

Was TODO.md item 7.6. smolvm defaults to deny-all guest egress with an explicit `allow_hosts` list; the same idea would
stop a compromised agent phoning anywhere but its intended API. Deferred rather than dropped because it is a separate
security feature with its own design questions (where the filter lives — guest nftables vs a host-side proxy on the
SLIRP path; how the allowlist is expressed per instance without entering the shared closure; how a `dev` guest still
reaches cache.nixos.org, npm, PyPI and crates.io, which is most of the internet by hostname). Nothing in S8–S11 widened
egress: the bridge NIC has no default route and no NAT to the LAN, so a guest's only way out is still SLIRP.

### S12 result — 2026-08-25

New `omp-broker-check` (in `dev.tools.omp-auth-broker`): a `systemd --user` oneshot + timer (3 min after boot, then
every 15 min) that watches the two ways the broker can be up and still useless, raises a **critical desktop
notification** (`notify-send`, from the newly-added `pkgs.libnotify` — this repo had no notification path at all before)
and exits non-zero so the failure is also visible in `systemctl --user status`:

1. **A disabled credential** — a refresh that failed definitively (`invalid_grant`). Reported per provider with its
   `disabledCause` and the fix (`omp auth-broker login <provider>`).
2. **Duplicate credentials for one provider** — the shape of the 2026-08-23 incident: a dead second `anthropic` row
   retried every 60 s beside the live one, which is how the good refresh token got rotated out.
3. Broker unreachable at all (curl failure) is reported too, pointing at `systemctl --user status omp-auth-broker`.

`notify-send` failures are swallowed on purpose — a headless or departed session must not turn a healthy broker into a
failed unit; the journal and the exit status carry the same news. The script honours `OMP_BROKER_URL` /
`OMP_BROKER_TOKEN_FILE` so it can be pointed at a test server, which is how it was verified.

**Verified 2026-08-25:**

1. Against the real broker: `omp-broker-check` → `ok (2 credentials, none disabled)`, exit 0; the timer is armed
   (`systemctl --user list-timers` shows the next run) and `systemctl --user start omp-broker-check` → `Result=success`.
2. Against a synthetic broker returning one disabled anthropic credential _and_ a duplicated provider: both problems
   reported with their causes, exit 1.
3. Against a dead port: "omp auth-broker unreachable", exit 1.
4. **Two providers, end to end from inside a guest** (no credential ever stored guest-side — `/run/agent.env` holds only
   `OMP_AUTH_BROKER_URL` + `OMP_AUTH_BROKER_TOKEN`): `omp -p --model haiku` → `SANDBOX_OK` (Anthropic OAuth) and
   `omp -p --model openrouter/openai/gpt-4o-mini` → `OPENROUTER_OK` (OpenRouter API key).

### S13 result — 2026-08-25

`scoite creds` now re-pushes df's **ssh config and git identity** into a running guest, not just the broker env. A
`Host` block added on abhaile after a sandbox booted used to need a stop/start to reach it.

- The guest-side install logic moved out of the boot units into commands (`scoite-install-ssh-conf`,
  `scoite-install-gitconfig`), because the same work now happens twice: at boot from the fw_cfg credential, and on every
  push. The CLI gained a small `push_file` helper (stream a staged host file over ssh, run an installer on it under
  `sudo -n`).
- Private keys still never enter a guest: the tar carries `sshconfig.local` plus the **public** halves of the keys it
  names, and authentication is the forwarded agent.
- Pushes run on `scoite creds`, on every `scoite ssh`, and on the 10-minute `scoite-creds` timer.

**Verified 2026-08-25** on the running `scoite-devtest`:

1. Deleted `~/.ssh/config.d` and every `*.pub` inside the guest → `sc creds devtest` → both restored, and `md5sum` of
   the guest's `sshconfig.local` equals the host's.
2. Pushed a tar with an extra `Host s13-test` block → a **new** guest shell resolved it (`ssh -G s13-test` →
   `hostname s13.example.invalid`, `user s13user`) with no restart; a subsequent `sc creds` push of the real config
   removed it again (`grep -c` → 0).
3. `ssh-add -l` in the guest lists the host agent's two keys; `ssh -T git@github.com` → _"Hi donskifarrell! You've
   successfully authenticated"_.
4. `~/.config/git/gitconfig.local` in the guest matches the host's md5 and `git config --get user.email` resolves.

### S14 result — 2026-08-25

Two halves.

**1. Host omp configuration is shared and propagated.** `omp config …` writes `~/.omp/agent/config.yml`; the CLI now
stages an `OMP_CONF` tar (new fw_cfg credential) and a guest command `scoite-install-omp-conf` unpacks it into
`/home/iosta/.omp/agent`, at boot and on every `scoite creds` push.

- The staging list is an **allow-list** — `config.yml agents skills rules prompts extensions hooks themes` — not a
  deny-list: `~/.omp/agent` also holds `agent.db` (session history), `models.db`, `sessions/`, `logs/`, and the broker
  token lives one directory up. A deny-list would ship whichever of those omp adds next.
- `models.yml` is deliberately excluded: the guest's copy points the `local` provider at the SLIRP gateway, and the
  host's (if it ever has one) describes providers as abhaile sees them.

**2. The models.yml hand-sync gotcha is gone.** Model ids, context windows and the per-model llama-server flags now live
in one data file, `modules/den/aspects/services/_llm-models.nix` (underscore ⇒ import-tree skips it). `llm.nix`
generates llama-server's router preset INI from it and `microvm-guest.nix` generates each guest's omp `models.yml` from
the same list (only entries flagged `omp = true` — the 8B is still excluded, with the reason in the data file). They
cannot drift any more.

Bug found and fixed while verifying: the new boot units called their installers **by name**, and a systemd unit's PATH
does not include `/run/current-system/sw/bin` — `scoite-install-omp-conf: command not found`, logged and then swallowed,
while the push path (a login shell) worked. All three units now call absolute store paths via `lib.getExe`; the commands
stay in `environment.systemPackages` for the push path. The same latent bug would have hit the S13 ssh/gitconfig units.

**Verified 2026-08-25:**

1. `nix build … services.llama-cpp.settings.models-preset` renders the same INI as before (multi-line comments correctly
   `;`-prefixed on every line), and `systemctl restart llama-cpp` came back `active` with `/v1/models` listing
   `llama-3.1-8b` and `qwen3.6-35b-a3b`.
2. The guest's generated `models.yml` contains exactly the qwen entry with `contextWindow: 65536`, `maxTokens: 8192` and
   `baseUrl: http://10.0.2.2:8080/v1`.
3. Boot path: `scoite-omp-conf`, `scoite-ssh-config`, `scoite-gitconfig` all `Result=success`; the guest's `config.yml`
   matches the host's and `omp config get theme.dark` → `titanium` on both.
4. Live path: `omp config set autoResume true` on the host → `sc creds devtest` → guest `omp config get autoResume` →
   `true`; set back to `false` → pushed → guest reports `false`. (Host settings left as they started.)
5. No credential material in the guest: `~/.omp/agent` holds only its own dbs plus `config.yml`/`models.yml`; no broker
   token, no sessions, no API keys in any yml.
6. `omp -p --model qwen3.6-35b-a3b` inside the guest → `LOCAL_OK` (the local llama-server round trip still works).

### S15 result — 2026-08-25

Not just a measurement in the end — the follow-up S5 left behind turned out to be a real misconfiguration.

**Nix picks substituters by priority, not by list order.** The guest listed `http://10.0.2.2:5000` (abhaile's harmonia)
_first_, but harmonia advertises `Priority: 50` by default, worse than cache.nixos.org's 40 — so a guest building
anything downloaded from the internet while the same paths sat on abhaile's disk (exactly what S5 caught:
`copying path '…cowsay…' from 'https://cache.nixos.org'`). Fixed in `virtualisation/microvm-host.nix` with
`services.harmonia.cache.settings.priority = 10`.

Worth keeping straight — there are **two** sharing mechanisms, and they cover different things:

- The **9p `ro-store` mount** (`/nix/.ro-store`) makes every host store path _visible_ in the guest, and it is live, so
  paths the host gains after boot appear too. But a path being visible is not the same as being registered in the
  guest's nix database: `nix path-info` on a host-built path reports "not registered", so nix will still want to
  _substitute_ it before a build can depend on it.
- **harmonia** is what serves that substitution, at loopback speed, from the exact same store. This is the piece the
  priority bug was silently disabling.

**Verified 2026-08-25:** `curl http://127.0.0.1:5000/nix-cache-info` → `Priority: 10`. Built three packages on abhaile
that the guest did not have (`figlet`, `sl`, `cmatrix`) and realised each inside the guest by store path:

- `nix-store -r …figlet…` → `copying path … from 'http://10.0.2.2:5000'`, and the NAR fetched from the same host.
- `cmatrix` realised in **0.48 s** with **zero** hits on cache.nixos.org / nix-community / numtide (grep count 0).
- Re-realising an already-copied path: 0.05 s.

### S16 result — 2026-08-25

`paseo-desktop` 0.4.0 (from `nix-ai-tools`, already wired into `apps.ai-tools`) **runs on abhaile** — no packaging
change needed. It launches under Wayland, and on start it brings up a paseo daemon of its own on `127.0.0.1:6767`.

That last detail matters and is _not_ a conflict: a sandbox's paseo is forwarded to its own private `127.x.y.1:6767`,
never to `127.0.0.1`, which is exactly why per-instance loopback addresses exist. The desktop app and any number of
guests can hold "port 6767" simultaneously.

**Gotcha worth remembering** (cost 20 minutes here): run from inside this agent session, `paseo-desktop` failed with
_"Electron failed to install correctly, please delete node_modules/electron"_, and with `ELECTRON_OVERRIDE_DIST_PATH`
set it failed differently (`electron_1.app` undefined). Neither is a paseo bug: the harness this agent runs in is itself
an Electron app and exports **`ELECTRON_RUN_AS_NODE=1`**, which makes every electron binary launched from that
environment run as plain node. `env -u ELECTRON_RUN_AS_NODE` and it starts normally. Any electron app tested from an
agent shell needs the same.

**Verified 2026-08-25:** `env -u ELECTRON_RUN_AS_NODE -u ELECTRON_NO_ATTACH_CONSOLE paseo-desktop` → the electron
process runs, its log shows `status: 'running', listen: '127.0.0.1:6767'`, and the UI's React Native layer initialises.
A guest's daemon stays reachable from the host by name at the same time
(`curl http://scoite-devtest.local:6767/api/health` → ok); pointing the desktop app at a guest daemon is a UI action,
not a configuration one.

### S17 result — 2026-08-25

> **Superseded in part on 2026-08-26**: herdr was dropped entirely (follow-up F1 below), so an interactive
> `ssh scoite-<name>` now lands in a plain fish shell that the login block has already `cd`'d to `/workspace`. The herdr
> config this step added is gone with it; the analysis below is kept because it explains why the obvious fix did not
> work.

Not the confirmation it looked like: interactive `ssh scoite-<name>` was landing in **/home/iosta**, not `/workspace`.

The login shell was innocent — `/etc/fish/config.fish`'s login block does `cd /workspace`, and the herdr _server_
process was measured with `/proc/<pid>/cwd = /workspace`. herdr simply does not inherit it: panes follow herdr's own
`terminal.new_cwd` policy, whose default (`"follow"`) falls back to **$HOME** whenever a pane has no source workspace to
inherit from — which is every pane of the first session after boot.

Fixes:

- `roles/sandbox.nix` (dev tier) now writes `~/.config/herdr/config.toml` with `[terminal] new_cwd = "/workspace"`,
  which covers panes, tabs and new workspaces alike.
- `dev.tools.herdr.autostart` keeps a `cd /workspace` before `exec herdr`, but its comment now says what it is actually
  for: the _non_-herdr shells (serial console, VS Code terminal, herdr absent). It never controlled pane cwd.

**Migration gotcha:** herdr persists its session in `~/.config/herdr/session.json`, which lives on the sandbox's
persistent home volume — so a sandbox that has already run herdr keeps its old $HOME-rooted workspace even after the
config lands. For existing sandboxes, once: `herdr server stop && rm ~/.config/herdr/session.json`. New sandboxes are
unaffected.

**Verified 2026-08-25** on `scoite-devtest`: with the config in place and the stale `session.json` cleared,
`herdr pane list` reports `"cwd":"/workspace"` and `"foreground_cwd":"/workspace"` for a pane created by an interactive
`ssh scoite-devtest` (before: `/home/iosta`). `fish -l -c pwd` → `/workspace`. Non-interactive
`ssh scoite-devtest <cmd>` still runs in `$HOME`, which is ordinary ssh behaviour and unchanged.

### S18 result — 2026-08-25

Measured first, then set. Idle guests, 2026-08-25:

| type    | in-guest RAM used | store overlay used | home used | qemu RSS |
| ------- | ----------------- | ------------------ | --------- | -------- |
| dev     | 513 MiB           | 906 MiB            | 7.3 MiB   | 1.63 GiB |
| minimal | 624 MiB           | 44 KiB             | 260 KiB   | 1.21 GiB |

Both memory and disk are _ceilings_, not reservations — qemu allocates guest RAM lazily with free-page reporting, and
both volumes are sparse images — so the point of per-type defaults is headroom, not thrift. `dev` keeps a build-sized
ceiling; `minimal`, which has no toolchain to build anything with, gets a small one:

| type    | cpu | mem MiB | disk MiB | home MiB |
| ------- | --- | ------- | -------- | -------- |
| dev     | 4   | 32768   | 32768    | 16384    |
| minimal | 2   | 4096    | 8192     | 4096     |

Implemented as `defaults_for <type>` in the CLI, applied in `scoite new` before the `--cpu/--mem/--disk/--home-disk`
overrides; usage text updated to show both columns.

**Verified 2026-08-25:** a fresh `sc new --type minimal` wrote `CPU=2 MEM=4096 DISK=8192 HOME_DISK=4096`, and in the
booted guest `nproc` → 2, `free -m` → 3918 MiB total, `/nix/.rw-store` → 7.8 G, `/home/iosta` → 3.9 G. qemu RSS **619
MiB** (down from 1.21 GiB with the old ceilings) and the whole instance occupied 136 MiB on disk. `nix flake check`
passes.

### S19 result — 2026-08-25

Documentation brought in line with what actually shipped.

- **`docs/microvm-sandbox.md`**: two types instead of four (with closures re-measured), the new command surface (`sc`,
  `rename`, `creds`, `expose --lan`, the new `list` columns), the naming/collision/rename rules, a rewritten
  **Networking** section for the two-NIC design (including the tailscale route hijack and the "never delete the bridge
  under a running guest" rule), new sections for **mDNS names**, **LAN exposure**, **host identity kept current** (the
  four fw_cfg credentials and what re-pushes them) and **the paseo daemon**, per-type disk/memory defaults, the harmonia
  `priority = 10` fix, and four new entries under Known quirks (herdr's `terminal.new_cwd` and its persisted session,
  `ELECTRON_RUN_AS_NODE`, the `scoite-<name>` identity, absolute paths in unit scripts).
- **`CLAUDE.md`**: the sandbox section rewritten around the shipped system — two types, the `scoite-<name>` identity,
  two NICs, `.local` names, opt-in LAN exposure, live identity propagation, the `_llm-models.nix` single source, and the
  herdr cwd rule — with a pointer to TASKS.md for the step-by-step history. Repo-layout line updated to
  `sandbox.{minimal,dev}`.
- **`TODO.md`**: item 7.5 closed (LAN exposure, done via S8/S11), 7.6 marked deliberately deferred (S20), item 13's
  header now records 13.0/13.2/13.3/13.4 as done and **13.1 (the read-write `hostkey` 9p share → `credentialFiles`) as
  the one still open**.
- **`docs/obsidian.md`**: `sc ~/vaults/main`, no hash-suffixed instance names, `dev` tier, and a correction — the guest
  _does_ have a git identity now (gitconfig rides in as a credential and is re-pushed by `sc creds`).
- **The `sandvm` shim is gone.** The package now installs `scoite` + `sc` only.

**Verified 2026-08-25:** `nix fmt` clean; `nix flake check` → "all checks passed!"; `nixos-rebuild switch` applied and
`ls .../scoite/bin` shows only `sc` and `scoite`; `sc list` works. `grep -rn sandvm` over the repo returns only
deliberate history: TODO.md's Done/phase-2 entries, GOAL.md (df's own words), TASKS.md, the dated notes in
docs/obsidian.md and CLAUDE.md, the `/var/lib/sandvm → /var/lib/scoite` migration in `microvm-host.nix`, the deploy.nix
comment explaining the old filter bug, and stale `.claude/settings.local.json` permission entries.

---

## Where this leaves the goals

Every step S0–S19 is verified and done; S20 (guest egress allowlisting) is deliberately deferred. Against
[GOAL.md](GOAL.md):

| Goal                                                             | Status                                                              |
| ---------------------------------------------------------------- | ------------------------------------------------------------------- |
| Rename to `scoite`, alias `sc`, `scoite-X` instances             | done (S2, S6)                                                       |
| Two VM types, `dev` the default                                  | done (S3)                                                           |
| `dev` has python/node/headless chromium + shell/git tools        | done (S3)                                                           |
| `dev` has omp with the host's configuration                      | done (S12, S14)                                                     |
| `dev` runs the paseo daemon (PR 3250 overlay)                    | done (S4)                                                           |
| direnv/devenv launched, dependencies installed                   | done (S5)                                                           |
| Existing `sandvm` features preserved                             | done (S2, verified per step)                                        |
| `list` shows the DNS name                                        | done (S10)                                                          |
| Rename a running instance; ssh + DNS follow                      | done (S7)                                                           |
| Expose VM services externally (`:5173`, `:6767`)                 | done (S11) — opt-in per port, URL is `abhaile.local:<port>`         |
| SSH lands in `/workspace`                                        | done (S17)                                                          |
| Connect to host llama.cpp for local models                       | done (S14 verification, generated from `_llm-models.nix`)           |
| Host runs `paseo-desktop`                                        | done (S16)                                                          |
| Provider logins via `omp auth-broker`, kept fresh, pushed to VMs | done (S12, S13)                                                     |
| SSH keys shared and propagated                                   | done (S13)                                                          |
| omp config shared and propagated                                 | done (S14)                                                          |
| Host nix store shared (no re-downloads)                          | done (S15) — the harmonia priority bug is what had been breaking it |
| Reach a VM by local domain name                                  | done (S9)                                                           |

### Closing state — 2026-08-25

Test sandboxes removed; the two df actually uses were recreated under the new scheme and verified running:

| name          | type | workspace                                                             | DNS                 | IP          |
| ------------- | ---- | --------------------------------------------------------------------- | ------------------- | ----------- |
| `scoite-main` | dev  | `/home/df/vaults/main` (the Obsidian vault agent, `vault-agent` abbr) | `scoite-main.local` | 10.77.0.174 |
| `scoite-mono` | dev  | `/home/df/dev/mono`                                                   | `scoite-mono.local` | 10.77.0.107 |

Both boot, accept ssh, and resolve by name. Their guest homes and store overlays start empty (the pre-rename instances
were deleted in S1 by df's decision); the archived agent configs from the old ones are in
`~/.local/state/scoite-preserve/*.tar.gz` if anything is wanted back.

Repo state: df committed the bulk of this work as `c1d9ab9 scoite` (2026-08-25 22:05). The changes made after that
commit — the S17 herdr cwd fix, the S18 per-type sizing, the harmonia priority fix, the shim removal, and the S19
documentation pass — are uncommitted in the working tree (`CLAUDE.md`, `TASKS.md`, `TODO.md`, `docs/microvm-sandbox.md`,
`docs/obsidian.md`, `modules/den/aspects/dev/tools/herdr.nix`, `modules/den/aspects/virtualisation/microvm-host.nix`,
`modules/den/roles/sandbox.nix`, `pkgs/by-name/scoite/package.nix`). They are all live on abhaile — every one of them
was applied with `nixos-rebuild switch` before being verified.

---

## Follow-ups after S19 (df, 2026-08-26)

### F1 — herdr dropped from host and guests

`dev.tools.herdr` is now included by **nothing**: removed from `roles.dev` (host) and from the `dev` tier's includes
(guests), along with the `dev.tools.herdr.autostart` hook and the `~/.config/herdr/config.toml` the tier was writing.
The aspect file `modules/den/aspects/dev/tools/herdr.nix` is kept intact and its header now says how to re-enable it
(one `includes` line each side) and what to remember if you do (its `terminal.new_cwd` policy and its persisted
`session.json` — the two traps from S17).

Consequences, all of them simplifications: an interactive `ssh scoite-<name>` runs plain fish, so the login shell's own
`cd /workspace` decides the landing directory again; there is no multiplexer session to go stale on the guest's home
volume; and `herdr --remote` is no longer a way to attach from the host.

**Verified 2026-08-26:** `type -P herdr` on abhaile finds nothing; in both guests `command -v herdr` → absent; an
interactive `ssh scoite-main` reports `pwd` = `/workspace` and `$SHELL` = fish. Docs updated (`docs/microvm-sandbox.md`,
`CLAUDE.md`, `docs/obsidian.md`).

### F2 — a guest's `omp` runs with the sandbox config overlay

df keeps a dedicated near-zero-approval overlay at `~/.omp/agent/config.sandbox.yml` ("use this ONLY inside a disposable
VM"), meant to be used as `omp --config ~/.omp/agent/config.sandbox.yml`.

- **Shipped in**: the CLI's `OMP_CONF` staging now also globs `config.*.yml` beside `config.yml`, so
  `config.sandbox.yml` (and `config.no-codex.yml`) ride in with the rest of df's omp configuration and are re-pushed by
  `scoite creds`. The glob is expanded against `$HOME/.omp/agent` explicitly — a glob in the `for` list would have been
  expanded against the current directory instead.
- **Used automatically**: `roles.sandbox.minimal` (so both tiers) installs a `pkgs.hiPrio (writeShellScriptBin "omp")`
  wrapper that execs the real omp with `--config "$HOME/.omp/agent/config.sandbox.yml"` when that file exists, and
  plainly otherwise. A wrapper rather than a shell alias because the callers that matter are not interactive shells —
  the paseo daemon spawning an agent, a systemd unit, `scoite ssh <name> -- omp -p '…'`. `hiPrio` resolves the `bin/omp`
  collision against `apps.ai-tools`' real omp in the same home-manager profile.

**Verified 2026-08-26:** both guests list `config.yml`, `config.sandbox.yml`, `config.no-codex.yml` in `~/.omp/agent`;
`command -v omp` resolves to the wrapper; a live `omp -p --model haiku` round trip answered `OMP_WRAPPER_OK`; and
reading `/proc/<pid>/cmdline` of the running process shows the real binary invoked as
`omp --config /home/iosta/.omp/agent/config.sandbox.yml -p --no-session --model haiku …`.

### F3 — `ping` needed root on abhaile (busybox was shadowing half the system)

Not a networking problem: `shell.bundles.system` installed **stock `pkgs.busybox`**, whose ~400 applet symlinks land in
df's home-manager profile — and `/etc/profiles/per-user/df/bin` comes _before_ `/run/current-system/sw/bin` on PATH. So
`ping` was busybox's applet, which opens a raw ICMP socket and needs root, instead of iputils' ping, which uses an
unprivileged ICMP datagram socket (`net.ipv4.ping_group_range = 0 2147483647` here, so any user may). Hence
`ping: permission denied (are you root?)`.

The same shadowing hit `ip`, `ps`, `tar`, `wget`, `top`, `find`, `awk`, `sed`, `du` and more — it is why several
commands in this very session failed oddly (busybox `tar` has no `--ignore-failed-read`, busybox `ip` no `-br`, busybox
`ps` no `-p`).

Fix: `pkgs.busybox.override { enableAppletSymlinks = false; }` — the package now ships only `bin/busybox`, so the
toolbox is still one `busybox <applet>` away and nothing is shadowed.

**Verified 2026-08-26:** `ping -c2 google.com` as df → 0% loss, no sudo; `type -P ip ps tar wget` all resolve to
`/run/current-system/sw/bin/…`, `df` to coreutils; `busybox` alone still prints its applet list.

### F4 — `scoite new --ssh` raced its own project pre-build

Reported by df 2026-08-26: `sc new --workspace . --ssh` in `~/dev/mono` booted the guest fine, then died inside it with
devenv's `× Failed to get shell attribute` under a 700-line nixpkgs-bootstrap trace.

**Cause: two concurrent devenv evaluations of the same project.** `scoite-workspace-init` starts at boot and evaluates
`/workspace`'s `.envrc`; `--ssh` then attaches, and direnv in the login shell starts a _second_ evaluation of the same
project against the same shared `.devenv/`. On this monorepo the pre-build took four minutes (20:52:29 → 20:56:32) and
the login landed squarely inside that window. Everything worked once both had finished, which is why a retry looked
fine.

Fixes:

- The guest's fish `loginShellInit` now waits while `scoite-workspace-init` is `activating` (printing why), bounded at
  20 minutes so a wedged pre-build cannot lock you out of the sandbox. It runs before direnv's hook, so the shell you
  get has the environment ready instead of paying for it twice.
- `scoite-workspace-init`'s PATH gained `/run/wrappers` and `/run/current-system/sw` — mono's devenv shells out to
  `sudo setcap` for caddy, and a systemd unit's PATH had neither, so it failed with `sudo: command not found` (the same
  class of bug as the credential installers in S14).
- Two deprecation warnings from earlier work, both visible in df's paste, are gone: `pkgs.hiPrio` → `lib.hiPrio` (F2's
  omp wrapper) and `services.resolved.llmnr` → `services.resolved.settings.Resolve.LLMNR` (S8).

**Known limit, documented rather than fixed:** `setcap` on a file under `/workspace` cannot work — virtiofsd runs
unprivileged, so `security.capability` xattrs are refused (`Invalid file … for capability operation`). It is non-fatal;
it only matters for binding ports < 1024 from a workspace binary.

**Verified 2026-08-26:** a purpose-built slow project (`.envrc` sleeping 75 s) reproduced the window — the login shell
printed `scoite: waiting for the project environment pre-build (scoite-workspace-init)…`, direnv only loaded after the
unit reached `success`, and the session landed in `/workspace` with the project's env var set. On the real
`scoite-mono`: `scoite-workspace-init` → `Result=success`, `sudo setcap` now resolves and runs (setcap itself still
refused by virtiofs, as above), and `devenv shell true` exits 0.

### F5 — `Permission denied (publickey)` into a running sandbox

Reported by df 2026-08-26. Not the sandbox's fault, and not a regression in the guest: **the host's ssh agent was
empty.**

The chain: a guest authorizes exactly one key, df's `aon.clan` (`modules/den/users/iosta.nix`); that private key is
**passphrase-encrypted** (`aes256-ctr`), so it is usable only through the agent; home-manager's `ssh-agent.service` is
restarted by `nixos-rebuild switch`, which drops every key added since login (it had last restarted at 21:48, minutes
before the failure); and the `scoite-*` ssh block named **no `IdentityFile`**, so with an empty agent ssh had nothing to
offer and the guest correctly refused. `ssh -i ~/.ssh/aon.clan` failed too, because the key cannot be decrypted without
the passphrase.

Fixes:

- `dev.tools.scoite` now sets `IdentityFile ~/.ssh/aon.clan` and `AddKeysToAgent yes` on the `scoite-*` block. An
  interactive `ssh scoite-<name>` asks for the passphrase once and puts the key back in the agent — which also restores
  agent-forwarded git inside the guest.
- The CLI says so up front instead of leaving a bare "Permission denied": `scoite start`/`new`/`ssh` print
  `the ssh agent holds no keys - … (or run: ssh-add ~/.ssh/aon.clan)` when `ssh-add -l` comes back empty.

**Verified 2026-08-26:** `ssh -G scoite-mono` reports `identityfile ~/.ssh/aon.clan`, `addkeystoagent true`,
`forwardagent yes`; `sc ssh mono` prints the warning while the agent is empty. Note the passphrase itself is df's to
type — with an empty agent the _unattended_ paths (`sc creds`, its 10-minute timer, `sc new --ssh`) still cannot connect
until one interactive ssh has unlocked the key. A passphraseless sandbox-only key would remove that limitation; it needs
a new sops secret and a change to what the guest authorizes, so it is df's call, not a default I picked.

### F6 — opensnitch: allow forever, not deny after 30 s

df (2026-08-26): "the defaults should be to allow the request forever, not 12h". The two halves of opensnitch had to be
set separately, and the aspect now documents which is which:

- **Daemon** (`services.opensnitch.settings`) — what it decides with no UI attached, or when the UI never answers:
  `DefaultAction = "allow"` (already upstream's value) and `DefaultDuration = "always"`. Upstream ships `"once"`, so an
  unattended allow evaporated immediately and the same connection re-prompted forever.
- **UI** (`~/.config/opensnitch/settings.conf`) — the popup's pre-selected action and duration. `default_duration` was
  `6`, which is **12h**: the combo is
  `0 once · 1 30s · 2 5m · 3 15m · 4 30m · 5 1h · 6 12h · 7 until reboot · 8 forever` (upstream's
  `DEFAULT_DURATION_IDX = 6` carries a stale `# until restart` comment — it is off by one). Now `8` = forever, with
  `default_action = 1` = allow (`ACTION_DENY_IDX = 0`, `ACTION_ALLOW_IDX = 1` in the UI's `config.py`). The 30 s
  countdown is kept — it is now a countdown to _allow forever_.

The UI rewrites that ini whenever any preference changes, so it cannot be a home-manager symlink; the two keys are
asserted on each activation by a `home.activation` entry (same mutable-seeded-file pattern as `dev/vscode.nix`), and
everything else in the file stays the UI's business. Changing those two in the GUI will be reverted on the next rebuild
— that is the trade for declaring them.

**Verified 2026-08-26:** the daemon's rendered config shows `DefaultAction: allow`, `DefaultDuration: always`; the UI
ini shows `default_action=1`, `default_duration=8`; `nix flake check` passes.
