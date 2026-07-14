# TODO

Repo task tracker. Each item should carry enough detail to hand off cold (to a person or a model). Migration
history/context lives in MIGRATION-STATUS.md; day-to-day conventions in CLAUDE.md.

## Open

### 1. Re-benchmark LLM backends after each `nix flake update`

RDNA4 (gfx1201) perf shifts with every llama.cpp/mesa/ROCm bump. Protocol + current numbers live in the
`modules/den/aspects/services/llm.nix` header; the winner is `services.llama-cpp.package` in the same file (currently
`llama-cpp-vulkan`; ROCm was already ahead on MoE prompt-processing, so the verdict may flip). Also re-check vLLM RDNA4
kernel support (vllm-project/vllm#28649) — if native gfx1201 kernels merge, vLLM becomes worth evaluating (it was
skipped 2026-07-03 because the gap was open; Ollama was measured slower than llama-server on the same weights and
dropped as a candidate). Also worth testing then: Qwen3.6-35B-A3B **MTP** GGUF + llama-server speculative decoding
(`--spec-type draft-mtp`) for a possible large tg boost.

### 2. Provision eachtrach (migration Phase 6)

Fresh Hetzner VPS, tailscale exit node, disposable. Decided 2026-07-14 (df): **x86 instance (2 vCPU / 4 GB RAM / 40 GB
disk), initial image = stock Ubuntu** (nixos-anywhere kexec's it into NixOS), custom apps run as **native NixOS
services** (not containers), some internet-exposed + some tailnet-only behind one Caddy (rewrite the orphaned
short-specific `services.web.caddy` aspect; `services.tailscale.permitCertUid = "caddy"` gets real certs for ts.net
names, normal ACME for public ones). Full recipe:

1. Create the VM; get root ssh access.
2. `nixos-anywhere --flake .#eachtrach root@<ip>` (needs `modules/den/hosts/eachtrach.nix` +
   `hosts/eachtrach/{disko.nix,facter.json}` — model on abhaile's; include `secrets.sops` + `services.tailscale` in its
   includes, plus an exit-node variant: `services.tailscale` currently hardcodes `exitNode = false`, parameterize or add
   an aspect variant).
3. On the new box: `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub` → uncomment + fill `&host_eachtrach` in
   `.sops.yaml`; uncomment the `secrets/eachtrach.yaml` creation rule if it gets per-host secrets; add it to the
   `shared.yaml` key group.
4. `sops updatekeys secrets/shared.yaml` (and any other file it must read).
5. Mint a **fresh** tailscale auth key (old ones expire ~90d) — as an exit node it likely wants its own key/secret
   rather than reusing `tailscale/aon_tailnet_authkey` (which is abhaile's peer key); add e.g.
   `tailscale/eachtrach_authkey` to shared.yaml or eachtrach.yaml and declare it in the exit-node aspect.
6. ~~Wire deploy-rs for day-2 (`deploy .#eachtrach`).~~ **Done 2026-07-14**: `modules/flake-parts/deploy.nix` — input +
   auto-generated `deploy.nodes` for every real host (hostname = bare host name, resolves via the tailscale /etc/hosts
   alias sync) + deployChecks in `nix flake check` + `deploy`/`nixos-anywhere` in the devshell. The eachtrach node
   appears automatically once its host file exists.

Additions from the 2026-07-14 repo review:

- **Bootloader**: `roles.default` pulls in `core.systemd.boot` (systemd-boot = UEFI-only). Hetzner Cloud x86 VMs (df's
  confirmed choice) boot legacy BIOS → eachtrach needs a grub disko/boot variant (GPT + `bios_boot` partition,
  `boot.loader.grub`) and must exclude/override `core.systemd.boot`.
- **Avoid the two-step secrets bootstrap**: instead of provision → read host key → updatekeys → redeploy, pre-generate
  eachtrach's SSH host keypair locally, compute its ssh-to-age recipient, updatekeys _first_, and hand the key to
  `nixos-anywhere --extra-files` (or `--copy-host-keys`) so the very first boot already decrypts sops secrets (tailscale
  joins immediately).
- **facter.json**: no need to model on abhaile's —
  `nixos-anywhere --generate-hardware-config nixos-facter hosts/eachtrach/facter.json` produces it during provisioning.
- Compose it from `roles.default` (now genuinely minimal — NM/avahi moved out 2026-07-14) + a new thin `roles.server`
  (systemd-networkd DHCP, maybe fail2ban) rather than any workstation role.

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
5. **(Optional) LAN-wide service exposure.** Currently sandvm's usermode networking only forwards to the host's
   loopback. If a guest-hosted dev server needs to be reachable from other devices on the LAN, swap to tap+bridge
   networking (like `virtualization.libvirt`'s `virbr0`) for that one interface.
6. **(Optional) Network egress allowlisting inside the guest.** smolvm (reviewed alongside microvm.nix when designing
   sandvm) defaults to deny-all guest network egress with an explicit `allow_hosts` list — worth mirroring for the
   cloud-LLM case in particular, so a compromised agent can't phone home anywhere but the intended API.
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
8. ~~Make the launch banner's `code --remote` hint actually work (VSCode Remote-SSH into guests).~~ **Done 2026-07-13**
   (details: docs/microvm-sandbox.md "VS Code Remote-SSH"). Three fixes: guest `programs.nix-ld.enable` (the downloaded
   VS Code server's node needs `/lib64/ld-linux-x86-64.so.2`, absent on NixOS) + a persistent per-instance
   `vscode-server.img` volume at `/home/iosta/.vscode-server` (ephemeral home would re-download the server every boot),
   both in `microvm-guest.nix`; host `dev.vscode` gained the `ms-vscode-remote.remote-ssh` extension and
   `remote.SSH.configFile` was re-pointed from `~/.ssh/sshconfig.local` to `~/.ssh/config` — the old value meant VS Code
   never saw the `Include ~/.ssh/config.d/*` line, so `sandvm-*` aliases resolved for the ssh CLI but not for VS Code.
   Host side needs `nixos-rebuild switch`; guests pick it up on next launch (running sandboxes must be stopped +
   relaunched).

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

### 13. sandvm follow-ups (from 2026-07-14 repo review; the lightweighting half is done)

Still open, independent items:

1. **Reuse the built runner on relaunch**: every `sandvm` launch pays a full impure NixOS eval (`nix build --impure`,
   tens of seconds) even when nothing changed. Cache the runner store path in the instance state dir keyed on (flake git
   rev + dirty-tree hash + cpu/mem/ports env tuple); reuse on match, `--fresh` flag to force.
2. **Replace the rw `hostkey` 9p share with a `microvm.credentialFiles` entry** (same fw_cfg mechanism as AGENT_ENV):
   guest oneshot installs it for sshd. Removes a whole virtio device and closes "guest root can read/corrupt the SSH
   host key shared by all instances" (share is currently rw; in-guest root is trivially reachable — iosta is wheel with
   password `iosta`).
3. **Instance-name double dash**: `name_for` in `pkgs/by-name/sandvm/package.nix` pipes `basename` through
   `tr -c 'a-zA-Z0-9' '-'`, which converts the trailing newline to `-` → names render `myproject--4a8bb99e`, not the
   single-dash form the docs/banner show. Fix: `tr -d '\n' | tr -c ...` or trim in bash. **Caveat**: fixing this changes
   every existing instance's identity (state dir, ssh alias, unit name) — old state dirs become orphans
   (`sandvm rm <old-name>` them) and any still-running old-name sandbox must be stopped via
   `systemctl --user stop sandvm-<old-name>`. Do it deliberately, not as a drive-by.
4. (Context, decided) Not worth switching hypervisor: qemu is load-bearing (SLIRP user networking + virtiofs + fw_cfg
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

## Done

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
