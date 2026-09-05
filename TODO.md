# TODO

Repo task tracker. Each item should carry enough detail to hand off cold (to a person or a model). Migration
history/context lives in MIGRATION-STATUS.md; day-to-day conventions in CLAUDE.md.

**The `sandvm`→`scoite` project has its own step-by-step tracker: [TASKS.md](TASKS.md)** (goals in [GOAL.md](GOAL.md)).
Items 7.5, 7.6 and 13.0–13.4 below are superseded by its steps — work them there, sequentially, each with its
verification, not from this file. Names below are pre-rename (`sandvm`), kept as written.

## Open

### 1. Re-benchmark LLM backends after each `nix flake update`

RDNA4 (gfx1201) perf shifts with every llama.cpp/mesa/ROCm bump. Protocol + current numbers live in the
`modules/den/aspects/services/llm.nix` header; the winner is `services.llama-cpp.package` in the same file (currently
`llama-cpp-vulkan`; ROCm was already ahead on MoE prompt-processing, so the verdict may flip). Also re-check vLLM RDNA4
kernel support (vllm-project/vllm#28649) — if native gfx1201 kernels merge, vLLM becomes worth evaluating (it was
skipped 2026-07-03 because the gap was open; Ollama was measured slower than llama-server on the same weights and
dropped as a candidate). Also worth testing then: Qwen3.6-35B-A3B **MTP** GGUF + llama-server speculative decoding
(`--spec-type draft-mtp`) for a possible large tg boost.

### 2. eachtrach hosted apps (the leftover of "provision eachtrach")

**The host itself is done** — eachtrach was _adopted in place_ on 2026-09-04 rather than reprovisioned (it had been
running since 2025-10-26 and is the live tailscale exit node; wiping it was never worth it). See the Done section and
the `## eachtrach` section of CLAUDE.md. What that closed: the host + role + aspects, per-host secrets, deploy-rs
transport, and the exit-node advertisement.

What is still open is only the _hosted apps_ half of the original item:

- Custom apps as **native NixOS services** (not containers), some internet-exposed and some tailnet-only, behind one
  Caddy. Rewrite the orphaned short-specific `services.web.caddy` aspect for eachtrach (item 12 tracks the orphan).
  `services.tailscale.permitCertUid = "caddy"` gets real certs for `ts.net` names; normal ACME for public ones.
- The clan-era caddy site was **dropped** by the adoption: it served `/srv/www/site/donalfarrell.com`, but
  `test.donalfarrell.com` had no DNS record any more and the apex points at GitHub Pages. `/srv/www` is still on the box
  (unserved), as is the removed `gh_deployer` SFTP user's home. Decide whether any of it is worth restoring before
  garbage-collecting it.
- Ports 80/443 are closed again (the firewall is now 22/tcp + 41641/udp only) — re-open them in the caddy aspect when
  something actually listens.

Notes for whoever picks this up:

- `roles.server` exists now and is the right base for a second VPS. It is `roles.default` with `core.systemd.boot`
  swapped for `core.boot.grub` and `core.home-manager` excluded. It deliberately does **not** configure networking —
  eachtrach pins `networking.useNetworkd` + `facter.detected.dhcp.enable` in its own host file because it was adopted,
  not installed. A genuinely _fresh_ VPS is the case where folding systemd-networkd DHCP into `roles.server` makes
  sense.
- For a fresh box, the 2026-07-14 review's advice still stands and was never exercised: pre-generate the host keypair
  locally, compute its ssh-to-age recipient, `sops updatekeys` **first**, then hand the key to
  `nixos-anywhere --extra-files` so the very first boot already decrypts secrets. `facter.json` comes from
  `nixos-anywhere --generate-hardware-config nixos-facter hosts/<host>/facter.json`.
- Keep new hosts off `secrets/shared.yaml` (see the Secrets gotchas in CLAUDE.md).

### 3. Back up the sops editor identity

`~/.config/sops/age/keys.txt` is the only copy of the editing key (`&admin_df`). Losing it doesn't lose data (any
recipient host can decrypt: `ssh-to-age -private-key < /etc/ssh/ssh_host_ed25519_key` as root), but fix it properly:

- Either store an offline/paper backup of `keys.txt`, or
- generate a second admin age key kept offline, add it as a recipient in `.sops.yaml`, then
  `sops updatekeys secrets/*.yaml`.

### 4. (Optional) Rename clan-era secret names

`ssh/aon_clan` (+`_pub`) → post-clan name. Touches encrypted data, so do as its own change: `sops secrets/shared.yaml`
(rename keys) → update the `homeFiles` map in `secrets/home.nix` → update whatever references `~/.ssh/aon.clan` inside
the encrypted `sshconfig.local`. Verify with the eval-diff method from MIGRATION-STATUS.md / plan notes.

### 5. Restore per-host toplevel build checks

`nix flake check` currently runs only treefmt + check-flake-file — the old `checks.nix` (per-host
`nixosConfigurations.<h>.config.system.build.toplevel` as a check) was lost in the flake-parts cleanup. Re-add a
`modules/flake-parts/checks.nix` that maps every `nixosConfigurations.<host>` toplevel into
`checks.<system>.host-<host>` (guard cross-system hosts), so `nix flake check` catches config breakage again. Until
then, verify hosts with `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`.

### 7. `sandvm` phase 2: agent harness + LLM wiring + git auth

`sandvm` (per-folder sandboxed microVMs, `docs/microvm-sandbox.md`) landed 2026-07-03 with the core sandbox only:
lifecycle, filesystem isolation, devenv/direnv/git, SSH + VSCode access, host-only port forwarding. Left open, each
independent enough to pick up separately:

1. ~~Package Pi and/or oh-my-pi for the guest.~~ **Done 2026-07-13**: added `nix-ai-tools` (numtide) as a flake input —
   it packages oh-my-pi as `omp` (upstream can1357/oh-my-pi) and `pi` (earendil-works/pi), no hand-rolled derivation
   needed. `omp` is in the guest's `environment.systemPackages` (`modules/den/aspects/virtualisation/microvm-guest.nix`)
   — guest-only, not installed on real hosts.
2. ~~Install herdr (herdr.dev, session multiplexer for coding agents) on both host and guest.~~ **Done 2026-07-13**:
   also from `nix-ai-tools`. Routed through `dev.tools.herdr` (homeManager) → `roles.dev` (abhaile's df) and
   `roles.dev-sandbox` (the guest's iosta) — one aspect, no duplication. `herdr --remote sandvm-<name>` from the host
   attaches to a guest's session over the ssh alias `sandvm` already sets up; herdr tunnels over plain ssh, no
   daemon/config needed on either end.
3. ~~Wire LLM access into the guest.~~ **Done 2026-07-13**, verified end-to-end (omp print-mode round trip through the
   sandbox to qwen on the GPU; details: docs/microvm-sandbox.md "LLM access for the agent harness"). Local: guests seed
   `~/.omp/agent/models.yml` at boot pointing omp's `local` provider at `http://10.0.2.2:8080/v1` (SLIRP gateway → host
   loopback → llama-server); **model ids/context sizes must be kept in sync with llm.nix's router presets by hand**.
   Cloud: optional host file `~/.config/sandvm/agent.env` (KEY=value, 0600, user-managed) → `microvm.credentialFiles`
   (qemu fw_cfg systemd credential, contents read at launch, never in /nix/store) → guest oneshot installs
   `/run/agent.env` → fish exports it → omp reads standard `*_API_KEY` vars. Follow-up if the 8B should be omp-usable:
   omp's harness overhead is ~17.1k tokens, over llama-3.1-8b's 16k `ctx-size` (400s on every request) — it's excluded
   from the guest's models.yml; raising the 8B's `ctx-size` in llm.nix would re-enable it (VRAM cost: KV cache roughly
   doubles; re-bench the fast lane before keeping).
4. ~~SSH-agent forwarding for git auth.~~ **Done 2026-07-13**, verified end-to-end (guest `ssh-add -l` lists the host
   agent's keys; `ssh -T git@github.com` from inside a sandbox authenticates as df; zero key files guest-side; details:
   docs/microvm-sandbox.md "Git auth"). The virtiofs idea was tested and **disproven** — a host-bound UNIX socket in the
   share is visible as an inode but guest `connect()` gets ECONNREFUSED (virtiofs shares the fs namespace, not socket
   endpoints) — so it's plain SSH `ForwardAgent` instead: `Host sandvm-*` block in `dev.tools.sandvm`'s HM module (must
   live there, not in the wrapper's config.d file, which is Include'd _after_ `Host *`'s `ForwardAgent no` and would be
   shadowed — first-match-wins), a stable `~/.ssh/agent.sock` symlink in the guest (herdr panes survive ssh reconnects),
   and github.com seeded into guest known_hosts. Host-side block needs a `nixos-rebuild switch` to land in
   `~/.ssh/config`; until then `ssh -o ForwardAgent=yes sandvm-<name>` behaves identically.
5. ~~**(Optional) LAN-wide service exposure.**~~ **Done 2026-08-25** (TASKS.md S8/S11): a second guest NIC on the host
   bridge `scoitebr0` plus `scoite expose --lan <port>` (iptables DNAT via a root helper, opt-in per port). Currently
   sandvm's usermode networking only forwards to the host's loopback. If a guest-hosted dev server needs to be reachable
   from other devices on the LAN, swap to tap+bridge networking (like `virtualization.libvirt`'s `virbr0`) for that one
   interface.
6. **(Optional) Network egress allowlisting inside the guest.** _Deferred deliberately 2026-08-25 — TASKS.md S20._
   smolvm (reviewed alongside microvm.nix when designing sandvm) defaults to deny-all guest network egress with an
   explicit `allow_hosts` list — worth mirroring for the cloud-LLM case in particular, so a compromised agent can't
   phone home anywhere but the intended API.
7. ~~Lean guest identity.~~ **Done 2026-07-13**: the guest user is now `iosta` (`modules/den/users/iosta.nix`,
   uid-pinned 1000 for the virtiofs `/workspace` share) carrying only `roles.dev-sandbox`
   (`modules/den/roles/dev-sandbox.nix`) — workstation's TUI shell slice + git + devenv/direnv + herdr + agent tools; no
   graphical apps, no zellij (herdr auto-starts on interactive SSH logins via `dev.tools.herdr.autostart`), and no more
   df-full-HM-identity in the guest. Also added: `sandvm-workspace-init` boot oneshot (microvm-guest.nix) that
   pre-builds a project's `devenv.nix`/`flake.nix` environment into the persistent store overlay, and direnv trusts
   `/workspace` so a project `.envrc` activates without `direnv allow`. The sandvm ssh alias now logs in as
   `User iosta`; console fallback is iosta/iosta. Remember: `sandvm` is HM-installed, so the new alias/User takes effect
   only after a `nixos-rebuild switch` on abhaile (and existing `~/.ssh/config.d/sandvm` blocks are rewritten on next
   launch).
8. ~~Make the launch banner's `code --remote` hint actually work (VSCode Remote-SSH into guests).~~ **Done 2026-07-15**
   (details: docs/microvm-sandbox.md "VS Code Remote-SSH"). Four fixes: guest `programs.nix-ld.enable` (the downloaded
   VS Code server's node needs `/lib64/ld-linux-x86-64.so.2`, absent on NixOS) + a persistent per-instance
   `vscode-server.img` volume at `/home/iosta/.vscode-server` (ephemeral home would re-download the server every boot;
   its mount root is chowned to iosta by a root oneshot — a tmpfiles `z` rule does NOT work there, see docs), both in
   `microvm-guest.nix`; host `dev.vscode` gained the `ms-vscode-remote.remote-ssh` extension + `remote.SSH.configFile`
   re-pointed from `~/.ssh/sshconfig.local` to `~/.ssh/config` (the old value meant VS Code never saw the
   `Include ~/.ssh/config.d/*` line, so `sandvm-*` aliases resolved for the ssh CLI but not for VS Code) +
   `remote.SSH.connectTimeout: 60` + — load-bearing with a fish login shell in the guest —
   `remote.SSH.useLocalServer: false`: the default local-server mode pipes the (bash) install script into the login
   shell, and fish rejects it at parse time (exit 127, nothing runs, VS Code reports only "Connecting with SSH timed
   out"); non-local-server mode runs `ssh <host> sh` explicitly instead. Also `remote.SSH.remotePlatform` with a
   wildcard `"sandvm-*" = "linux"` entry (stops the per-instance platform prompt), and settings.json is now installed as
   a **mutable seeded file** via `home.activation` instead of HM's read-only symlink — in non-local-server mode the
   extension writes an exact-hostname remotePlatform entry after every connect (its save guard is wildcard-unaware),
   which nags forever against a read-only file; details in the docs. Host side needs `nixos-rebuild switch`; guests pick
   changes up on next launch (running sandboxes must be stopped + relaunched).

### 8. VPS provision/update wrapper tool (port `nix-flake-install` from sini-nix)

df (2026-07-14): eachtrach and future VPSs start from stock Ubuntu images and need remote install (nixos-anywhere
kexec) + day-2 updates (deploy-rs, now wired — see `modules/flake-parts/deploy.nix`) — "a tool to wrap that all up would
be useful". The natural shape: one `pkgs/by-name` CLI that, given a host name + IP, does the whole item-2 sequence —
pre-generate host SSH keypair → add ssh-to-age recipient to `.sops.yaml` → `sops updatekeys` →
`nixos-anywhere --extra-files` (host key in place, first boot decrypts, tailscale joins) → verify `deploy .#<host>`
works. Prior art to port: `/home/df/dev/sini-nix/pkgs/by-name/nix-flake-install/` (+ its `.sh`), currently excluded in
`modules/flake-parts/pkgs.nix` because it needs:

- a port of sini-nix `pkgs/by-name/nix-flake-provision-keys` (key provisioning helper), and
- reworking its agenix-rekey workflow to this repo's sops-nix flow (host recipient = ssh-to-age of the target's host
  key; `sops updatekeys` instead of rekey).

Un-exclude in `modules/flake-parts/pkgs.nix` once it builds.

### 9. Purge migration leftovers (plaintext secrets on disk)

`.migration-staging/plaintext/` still holds **unencrypted** copies of migration-era secrets (df's SSH private key,
password + emergency-access plaintext, host keys) from June — gitignored, but sitting in the working tree since the
migration finished. Securely delete it (`shred -u` the files / `rm -rf` at minimum), and archive or delete
`MIGRATION-STATUS.md` + the rest of `.migration-staging/` (migration is complete; anything still-relevant is already in
CLAUDE.md/TODO.md).

### 12. Decide wire-or-delete for the orphaned aspects

Aspects defined but included by no host/role/user (inert, several carry stale legacy references): `services.web.caddy`
(still "short"-specific — rewrite for eachtrach, see item 2), `services.paperless`, `services.cosmic`,
`virtualisation.vm-login`, `gaming.steam`, `gaming.alvr`, `apps.yt-dlp`, `apps.zathura`. steam/alvr staying orphaned is
**intentional for now** (df 2026-07-14: will game on abhaile eventually, not yet — re-add a gaming include and the
`steam-config-nix` input then). The rest: delete or wire when their host materialises.

### 13. sandvm follow-ups

> **Superseded by [TASKS.md](TASKS.md)** (2026-08-24/25). Status as of 2026-08-25: 13.0/13.2 **done** (S1 — both
> pre-rework instances removed, agent configs archived to `~/.local/state/scoite-preserve/`), 13.3 **done** (S12 —
> `omp-broker-check` timer + desktop notification), 13.4 **done** (S18 — per-type sizing). **Still open: 13.1**, the
> read-write `hostkey` 9p share → `microvm.credentialFiles`. Track status in TASKS.md, not here.

Items 1 (runner reuse) and 3 (instance-name double dash) were closed by the 2026-08-22 rework — see Done. Still open:

0. **Restart the two pre-existing sandboxes to pick up the networking rework** (2026-08-22, low effort, do first).
   `main-e57b201a` and `mono-18915ff1` still run the old scheme: forwards bound to `0.0.0.0` (LAN-visible) and a guest
   firewall that DROPs everything but ssh. Both migrate automatically on their next `sandvm start` — they get an `ADDR`,
   ssh moves to 2222, and `sandvm list` stops printing `(on next start)`. Until they do, their `0.0.0.0:5173` /
   `0.0.0.0:24123` / `0.0.0.0:29162` bindings also block those ports for **every** other sandbox (a wildcard listener
   covers all 127.x addresses), so `effective_ports` silently drops them from new launches. Needs a
   `nixos-rebuild switch` first — `sandvm` is home-manager-installed, so CLI edits do not reach `$PATH` without one.

1. **Replace the rw `hostkey` 9p share with a `microvm.credentialFiles` entry** (same fw_cfg mechanism as AGENT_ENV /
   CLAUDE_CREDS): a guest oneshot installs it for sshd. Removes a whole virtio device and closes "guest root can
   read/corrupt the SSH host key shared by all instances" (the share is currently rw, and in-guest root is trivially
   reachable — iosta is wheel with password `iosta`).
2. **Retire the legacy state dirs.** `sandvm list` shows `-dotfiles--608a3d81`, `lsit--1eb9652b`, `main--e57b201a`,
   `mono--18915ff1`, `ynab--e8009d75` as type `legacy` — pre-rework layouts that can't be started (different volume set,
   different guest hosts). `mono--18915ff1` is ~9.9 G and `main--e57b201a` ~1.1 G on disk. `sandvm rm <name>` each once
   df confirms nothing in them is wanted; `docs/obsidian.md`'s vault agent must then be recreated
   (`sandvm ~/vaults/main`, which now creates a `devenv` sandbox with a persistent home).
3. **Surface a disabled omp broker credential** (2026-08-23, from the credential-refresh work). When an Anthropic OAuth
   refresh fails definitively (`invalid_grant` — Anthropic rotates the refresh token on every use, so a second holder of
   the same grant invalidates yours), the broker sets `disabled_cause` on the row and every consumer, host and guests
   alike, silently loses omp until df happens to notice and re-runs `omp auth-broker login anthropic`. It happened on
   abhaile 2026-08-23 09:03 and was invisible except in the journal. Wanted: something that makes it loud — e.g. a
   `systemd --user` timer polling
   `curl -H "Authorization: Bearer $(cat ~/.omp/auth-broker.token)" http://127.0.0.1:8765/v1/credentials/disabled` (plus
   the snapshot, to catch **duplicate/stale anthropic rows** — abhaile had a dead one being retried and finally disabled
   every 60s for hours alongside the live one) and failing the unit / writing a desktop notification when the list is
   non-empty. No notification infrastructure exists in this repo yet (no `notify-send`, no libnotify), which is why this
   was left out of the 2026-08-23 fix rather than built blind. Everything else on that path is already live: the broker
   re-reads its store on login (no restart needed since omp ≥17.4.2), guests query it per request, and `sandvm creds`
   keeps a running guest's bearer token current.
4. **Per-type default sizing.** All four types currently share `--cpu 4 --mem 32768 --disk 32768 --home-disk 16384`. A
   `minimal` sandbox almost certainly wants less; worth measuring actual use before picking numbers.
5. (Context, decided) Not worth switching hypervisor: qemu is load-bearing (SLIRP user networking + virtiofs + fw_cfg
   credentials — firecracker has no virtiofs, cloud-hypervisor no SLIRP), and `microvm.qemu.machine` already defaults to
   the slim `microvm` machine type on x86_64.

### 15. Add the macbook (nix-darwin) host

df (2026-07-14): a MacBook Pro will join the fleet on nix-darwin + homebrew. The unused-but-kept inputs (`nix-darwin`,
`nix-homebrew`, `homebrew-core`, `homebrew-cask`, `nix-rosetta-builder`) exist for this. Den supports darwin classes
(`den.aspects.<x>.darwin`; several core aspects — nix.nix, openssh — already carry `darwin` blocks). Needs: a
`den.hosts.aarch64-darwin.<name>` host file, a homebrew aspect wiring nix-homebrew + the taps, deciding which roles
apply (workstation minus NixOS-only aspects), and `nix-rosetta-builder` if linux-builder VMs are wanted for x86 builds.

### 16. (Optional) ucodenix for newer Raphael microcode on abhaile

Reviewed 2026-07-14. Early microcode updates already work on abhaile via `hardware.cpu.amd.updateMicrocode` +
linux-firmware (boot log: `Updated early from: 0x0a601209` → running `0x0a60120a`; BIOS carries 1209). But platomav's
CPUMicrocodes (ucodenix's source) has **`0x0A60120C`** (2024-11-10) for this exact stepping (`cpu00A60F12`) — two
revisions ahead of what linux-firmware ships. If wanted without a BIOS flash: re-add `github:e-tho/ucodenix` as an
input, `services.ucodenix.enable = true` + `services.ucodenix.cpuModelId = "00A60F12"` (it can also read
`hosts/abhaile/facter.json` directly) in `hardware.cpu.amd` or its own aspect. Trade-off: one more input, microcode
binaries sourced from BIOS-extraction aggregation rather than AMD's linux-firmware channel (still AMD-signed).
nixos-hardware was reviewed at the same time and stays pruned: its AMD profiles are a strict subset of the existing
`hardware.*` aspects (`updateMicrocode`, `hardware.graphics`, fstrim) and kernel 7.1 already defaults `amd-pstate-epp`
active (verified live) — nothing left for it to add on a custom desktop; re-add only if a NixOS _laptop_ joins the fleet
(its per-model laptop quirk profiles are the actual value).

### 17. Obsidian vault follow-ups (setup 2026-07-14; architecture: docs/obsidian.md)

Aspects `apps.obsidian` + `services.syncthing` landed; sandvm reused unchanged (`vault-agent` abbr). Remaining, in
order:

1. **One-time bootstrap** (df, manual): follow the ordered checklist in docs/obsidian.md — switch, then git init +
   `gh repo create vault-main --private`, vault `CLAUDE.md`, install the obsidian-git community plugin (auto
   commit-and-sync ~10 min; plugins are manual on purpose — HM-installed ones are store symlinks that break
   Syncthing→Android).
2. **Pair the Android phone**: read the device ID off Syncthing-Fork, fill `devices.phone.id` and the folder's
   `devices = [ "phone" ]` in `modules/den/aspects/services/syncthing.nix`, switch, accept the share on the phone, open
   in Obsidian mobile; disable obsidian-git's automatic routines on the phone (per-device toggle).
3. (Optional) adopt the staged sops syncthing identity + GUI password (`secrets/abhaile.nix` commented entries — owner
   df) if a declarative device ID matters; today syncthing self-generates on first start.
4. (Optional) git-commit backstop: systemd --user timer running `git -C ~/vaults/main add -A && git commit && git push`
   when Obsidian hasn't been running (obsidian-git only commits while the app is open).
5. **Phone→agent inbox (design)**: phone edits `inbox.md` / drops files into `drop/` (both sync in); a systemd --user
   _path unit_ on abhaile watches the synced path and triggers a oneshot running headless Claude in the sandbox
   (`ssh sandvm-main--<hash> -- claude -p 'process /workspace/inbox.md'`; sandbox pre-launched or lazy-launched by the
   unit). Needs: locking/idempotency, a processed-marker convention, and treating inbox content as untrusted input.
6. **Telegram bot (design, after 5)**: bot (abhaile now, eachtrach later; token in sops) bridging chat ↔ the same inbox
   convention — append message, trigger agent, reply with the agent's answer. Strictly additive to item 5.
7. **MacBook wiring (with item 15)**: HM `services.syncthing` user service on darwin with the same folder id
   `vault-main`; `apps.obsidian` is already portable (registers the vault via the HM module's darwin paths).

### 18. Drop the `llmfit` version-pin overlay when nixpkgs catches up

Added 2026-08-29. `modules/den/aspects/services/_llmfit.nix` pins `llmfit` to **1.1.12** (upstream latest) because the
locked FlakeHub-weekly nixpkgs ships 1.1.8; it is applied by `services/llm.nix`, which also puts `pkgs.llmfit` in
abhaile's `environment.systemPackages`. Check after a `nix flake update`: comment out the `nixpkgs.overlays` line in
`llm.nix` and run `nix eval .#nixosConfigurations.abhaile.pkgs.llmfit.version` — if nixpkgs is at or past the version
you want, delete `_llmfit.nix`, the overlay line, and the two doc paragraphs (docs/llm.md "Bump the pinned `llmfit`" +
the CLAUDE.md LLM gotcha). Otherwise bump the pin instead: version, src hash (`nix-prefetch-url --unpack` the tag
tarball → `nix hash convert --to sri`), then `cargoDeps.hash` from a fake-hash build. `cargoHash` itself is NOT
overridable — `buildRustPackage` reads it off `args`, not `finalAttrs`.

## Done

- 2026-09-04 — **eachtrach adopted into Den in place** (closed the host half of item 2; migration Phase 6, by a
  different route than planned). The machine was never reprovisioned: it had been running since 2025-10-26 off a
  clan.lol bootstrap and is the tailnet's exit node, so it was brought under Den as-is. Reference + gotchas: the
  `## eachtrach` section of CLAUDE.md. What changed:
  - **Host data recovered, not regenerated**: `hosts/eachtrach/{disko.nix,facter.json}` came verbatim out of git
    (`220c93e^:machines/eachtrach/…`). Verified before deploying — the layout's derived partlabels (`eaab…`→sda3,
    `21d8…`→sda2) match the live `/dev/disk/by-partlabel` exactly.
  - **`roles.server`** (new): `roles.default` with `core.systemd.boot` excluded in favour of **`core.boot.grub`** (new)
    — Hetzner Cloud x86 boots legacy BIOS. `core.home-manager` is excluded too: with no users declared, Den's HM battery
    never imports the module and its settings fail to evaluate. Den's `excludes` resolves through roles.default's nested
    include, confirmed by eval.
  - **`services.tailscale` split into three aspects**: the base daemon (now secret-free), `…​.authkey` (shared.yaml,
    abhaile's) and `…​.exit-node`. The dead `exitNode`/`networking.nat` block is gone — tailscaled does its own
    exit-node SNAT, and the old code guessed the wrong interface anyway. Verified a no-op for abhaile: identical unit
    set, byte-identical tailscale units, only the flake-source path inside sops-nix's manifest differs.
  - **Secrets**: `secrets/eachtrach.yaml` + `secrets.eachtrach`, encrypted to `&admin_df` and a new `&host_eachtrach`.
    eachtrach is deliberately **not** a `shared.yaml` recipient. Its age identity is the pre-existing ssh host key,
    which lived only on a clan tmpfs and was copied to `/etc/ssh/ssh_host_ed25519_key` — so the machine's ssh
    fingerprint never changed.
  - **Deploys go to the public ip**, via a new `deployHost` override in `modules/flake-parts/deploy.nix`: Tailscale SSH
    intercepts port 22 on the tailnet behind an interactive check, which hangs a non-interactive `deploy`.
  - **Dropped**: the clan-era caddy site, `gh_deployer`, and the `mise` account (see item 2 for what to do about
    `/srv/www`). Kept: tailscale identity/prefs, root's password, the network setup, the ssh host key.
  - Verified end to end: `nix flake check`, `deploy --dry-activate`, `deploy`, then a **reboot** — comes back on kernel
    6.18.44 with no failed units, default route intact, exit node advertising `0.0.0.0/0 + ::/0`, and sops decrypting
    from a cold boot. **Known first-switch failure** off a 25.11 clan system: root's user `dbus-broker.service` fails to
    reload (25.11→26.11 swaps dbus-daemon for dbus-broker) and deploy-rs rolls back — just run `deploy` again.
  - Still open: `boot.initrd.systemd.enable` is pinned `false` to match the adopted box while this nixpkgs defaults it
    true. Flip it as its own reboot-verified step.

- 2026-08-22 — **sandvm rework: four types, real lifecycle, shared closures** (closed items 13.1 and 13.3). Full
  writeup: `docs/microvm-sandbox.md`. What changed:
  - **Four guest types** (`modules/den/roles/sandbox.nix`, nesting tiers `minimal` ⊂ `generic` ⊂ `devenv` ⊂
    `workstation`; closures 3.0 / 6.8 / 9.2 / 9.7 GiB), one Den host each (`modules/den/hosts/sandvm.nix`), each
    emitting `packages.sandvm-guest-<type>`. `roles/dev-sandbox.nix` is gone; `users/iosta.nix` is now tier-independent
    and the tier is attached per host — both to the host (for `nixos` keys) and to `users.iosta` (for `homeManager`
    keys). **Den gotcha found doing this**: entities take a single `aspect` _value_; a free-form `includes` on
    `den.hosts.<sys>.<name>` is silently ignored (it evaluated fine and produced four identical toplevels).
  - **CLI**: `sandvm new|start|stop|rm|ssh|list|resize`, named instances with an optional `--workspace` folder, `--ssh`
    to boot-and-attach, `--type`, `--disk`/`--home-disk`, per-instance `config` file so `start` remembers a sandbox's
    shape. `sandvm <path>` still works (the `vault-agent` abbr).
  - **Instance-independent system closure**: every per-launch value now only touches runner-side `microvm.*` options,
    verified by evaluating `system.build.toplevel.drvPath` under two different env tuples and getting the same path. The
    enabler was making `networking.hostName` the static string `sandbox` and delivering the real name as a boot
    credential. Combined with a fingerprint-keyed runner cache (`runner.key`, `--out-link` doubling as a GC root),
    relaunch went **~11 s → ~2.6 s** and no longer rebuilds a NixOS generation per instance.
  - **Persistent `/home/iosta` volume** (df's call) replacing the tmpfs home + the separate `vscode-server.img`; tool
    installs, shell history and agent state survive stop→start.
  - **Disks grow**: sparse images (a fresh 4 G + 2 G pair occupies ~134 MiB), `sandvm resize` truncates + issues a QMP
    `block_resize` to a live qemu, and the guest's `sandvm-grow-fs` unit + 2-minute timer stretches the filesystem — no
    host→guest signalling needed. Verified live via `query-block`.
  - **Host binary cache**: `services.harmonia.cache` on `127.0.0.1:5000` (`virtualisation/microvm-host.nix`), guests
    substitute from `http://10.0.2.2:5000` unsigned with `require-sigs = false` — they already mount that store
    read-only, so it grants nothing new and needs no signing key.
  - **claude-code credentials** (df's call): `~/.claude/.credentials.json` copied in per launch over fw_cfg, so
    sandboxes are zero-touch. Trade-off documented in the "what's deliberately NOT shared" section.
  - Sessions now land in `/workspace` (fish `loginShellInit`, before herdr's autostart).
  - Pre-rework state dirs list as type `legacy` and are not startable — item 13.2.

- 2026-07-14 — **`roles.default` split** (was item 11): `core.network.manager` + `core.network.avahi` moved to
  `roles.workstation` (df-approved); the sandvm guest now runs systemd-networkd DHCP (`networking.useNetworkd` +
  `wait-online.anyInterface` in `microvm-guest.nix`). `core.systemd.boot` deliberately stayed in roles.default (every
  current consumer wants it; eachtrach overrides it — item 2). Verified: nix-diff of abhaile's toplevel pre/post shows
  zero avahi/NM deltas (only the intentionally-changed sandvm package chain); sandvm-guest builds clean. Den's
  `primary-user` battery still lists a now-nonexistent `networkmanager` group for iosta — NixOS drops unknown groups,
  harmless.

- 2026-07-14 — **sandvm lightweighting, first batch** (was item 13.1/2/5/7): NM/avahi out of the guest (above);
  `microvm.balloon = true` + `--mem` default raised 4096 → **32768** per df ("use my resources, don't restrict") —
  microvm.nix's qemu runner sets `free-page-reporting=on`, so mem is a lazy-allocated cap and freed guest pages return
  to the host automatically (fixed cost: guest struct-page array ~1.5% of cap); duplicate guest `omp` systemPackages
  entry removed (apps.ai-tools already installs it, and on real hosts too — stale "guest-only" doc claims fixed);
  agent.env now created under `umask 077` (was briefly world-readable with API keys). Also swept the deprecated
  `pkgs.system` → `pkgs.stdenv.hostPlatform.system` in dev/tools aspects. Running sandboxes pick everything up on next
  relaunch after abhaile's `nixos-rebuild switch`.

- 2026-07-14 — **deploy-rs wired + dead inputs pruned** (was items 10 + part of 2): new `modules/flake-parts/deploy.nix`
  (deploy-rs input, auto-generated `deploy.nodes` for every real host, deployChecks in `nix flake check`), `deploy` +
  `nixos-anywhere` added to the devshell — README's claims about both are now true. Pruned 7 dead inputs
  (firefox-addons, nix-flatpak, nixidy, nixos-hardware, steam-config-nix, stylix, ucodenix); kept
  nix-darwin/homebrew-core/homebrew-cask/nix-homebrew/nix-rosetta-builder for the planned macbook (item 15) and
  nixos-anywhere for provisioning (item 2). flake.nix regenerated via write-flake; `nix flake lock` pruned the lock (no
  version bumps).

- 2026-07-14 — **doc drift fixed** (was item 14): CLAUDE.md (treefmt formatter list, den.nix wiring description,
  machines table marks eachtrach/macbook as planned, deploy/flake-check command notes) and README (flake-check claim,
  deploy node note, machines table) corrected, and the stale role/user file headers (`roles/dev.nix` "role-server",
  `roles/desktop.nix` "scratchpad", `users/df.nix` "devbox") rewritten.

- 2026-07-14 — **delta/difftastic aspects wired** (was item 6): both are included by `roles.workstation` and
  `roles.dev-sandbox`; abhaile's toplevel dry-run-evals clean with them (`programs.delta` / `programs.difftastic` are
  valid current HM options).

- 2026-07-03 — **Kernel 7.1.0 re-bench** (was item 1): rebooted onto `linuxPackages_latest` from the weekly; full matrix
  re-run (8B + Qwen3.6 both backends). No regression, no verdict change — all numbers within a few % of 6.18.35 (tables
  in docs/llm.md). Kernel bump kept.

- 2026-07-03 — **nixpkgs converged on the FlakeHub weekly** (was TODO item 3, resolved differently): root `nixpkgs` now
  points at the same `DeterminateSystems/nixpkgs-weekly` URL as `nixpkgs-unstable` (flake-file can't render a root-level
  `follows`), so host modules+packages and all input `follows` share one cooldown-protected source; host release string
  is now 26.11-pre. `services.llama-cpp` migrated to the freeform `settings` module shape in the same change. See
  CLAUDE.md "nixpkgs wiring".

- 2026-07-03 — **abhaile switched onto the simplified secrets plumbing** (was TODO item 1): activation diff matched
  expectations (df:users ownership, 0600 private keys, `secrets` group gone). Smoke-tested: `ssh -T git@github.com`
  authenticates via `~/.ssh/df_gh`, tailscaled active, `/run/secrets/*` correct.
- 2026-07-03 — **Local LLM inference landed on abhaile** (aspects `hardware.gpu.rocm` + `services.llm`): llama.cpp
  Vulkan + ROCm side by side, benchmarked on-box (protocol + numbers in `modules/den/aspects/services/llm.nix` header);
  default = llama-server + Vulkan on 127.0.0.1:8080 (OpenAI-compatible). Vulkan tg +24% vs ROCm on 8B Q4_K_M; ROCm ahead
  on MoE pp. Ollama measured slower at same weights; vLLM skipped (RDNA4 kernel gap open).

- 2026-07-02 — Secrets review: decided to **stay on sops-nix** (over agenix/agenix-rekey; identical age identity model,
  working setup, `neededForUsers` + multi-secret YAML in use). Simplified plumbing: base wiring aspect, single-map
  `secrets/home.nix` (was 3 declarations per secret across 2–3 files), tailscale secret moved next to its consumer,
  `secretsUser.enable` flag removed (dendritic), stale docs fixed, ssh-to-age/age added to devshell. Verified: eval-diff
  of `sops.secrets` + tmpfiles vs pre-refactor baseline (only intended owner/group/mode deltas), abhaile toplevel
  builds, `nix flake check` green (after fixing the pre-existing homeModules breakage, see item 6).
