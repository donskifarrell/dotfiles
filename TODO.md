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

Fresh Hetzner VPS, tailscale exit node, disposable. Full recipe:

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
6. Wire deploy-rs for day-2 (`deploy .#eachtrach`).

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

### 6. Wire up (or delete) the delta/difftastic shell aspects

2026-07-02: `shell/delta.nix` + `shell/difftastic.nix` were dead `flake.homeModules` leftovers that broke
`nix flake check` (no `flake.homeModules` option exists since the HM flakeModule was removed); they're now proper Den
aspects (`den.aspects.shell.{delta,difftastic}.homeManager`) but **no bundle/host includes them**, so they're inert.
Either add them to `shell.bundles.base` / `dev.git` (verify the home-manager option names still exist when doing so —
they were never evaluated while dead) or delete them (the `dev.git` header claims they were merged there, but git.nix
contains no delta/difftastic config).

### 7. `sandvm` phase 2: agent harness + LLM wiring + git auth

`sandvm` (per-folder sandboxed microVMs, `docs/microvm-sandbox.md`) landed 2026-07-03 with the core sandbox only:
lifecycle, filesystem isolation, devenv/direnv/git, SSH + VSCode access, host-only port forwarding. Left open, each
independent enough to pick up separately:

1. **Package Pi and/or oh-my-pi for the guest.** Neither is in nixpkgs yet (earendil-works/pi, and a fork of
   can1357/oh-my-pi — check which fork is canonical before packaging). Check whether either ships its own
   `flake.nix`/`packages` output first (add as a flake input + reference its package directly) before hand-rolling a
   derivation. Add to `modules/den/aspects/virtualisation/microvm-guest.nix`'s `environment.systemPackages` once
   packaged.
2. **Wire LLM access into the guest.** Local: abhaile's llama-server is already reachable from any sandvm guest at
   `http://10.0.2.2:8080/v1` (qemu usermode networking forwards the guest's gateway address to the host's loopback —
   verified, no `llm.nix` change needed). Cloud: BYOK key needs to reach the guest at runtime without landing in the
   world-readable `/nix/store` — pass it via a runtime-written share or systemd credential, not baked into the Nix
   config.
3. **SSH-agent forwarding for git auth.** Right now sandvm guests get none of df's real SSH/git private keys
   (deliberately — see docs/microvm-sandbox.md, "what's deliberately not shared"), so git push/pull from inside a
   sandbox has no auth. Forward the host's `SSH_AUTH_SOCK` into the guest (virtiofs can proxy a live UNIX socket; verify
   this works in practice) instead of copying key material in.
4. **(Optional) LAN-wide service exposure.** Currently sandvm's usermode networking only forwards to the host's
   loopback. If a guest-hosted dev server needs to be reachable from other devices on the LAN, swap to tap+bridge
   networking (like `virtualization.libvirt`'s `virbr0`) for that one interface.
5. **(Optional) Network egress allowlisting inside the guest.** smolvm (reviewed alongside microvm.nix when designing
   sandvm) defaults to deny-all guest network egress with an explicit `allow_hosts` list — worth mirroring for the
   cloud-LLM case in particular, so a compromised agent can't phone home anywhere but the intended API.

### 8. Port `nix-flake-install` from sini-nix

Excluded in `modules/flake-parts/pkgs.nix` because it needs:

- a port of sini-nix `pkgs/by-name/nix-flake-provision-keys` (key provisioning helper), and
- reworking its agenix-rekey workflow to this repo's sops-nix flow (host recipient = ssh-to-age of the target's host
  key; `sops updatekeys` instead of rekey).

Source: `/home/df/dev/sini-nix/pkgs/by-name/nix-flake-install/` (+ its `.sh`). Un-exclude in
`modules/flake-parts/pkgs.nix` once it builds.

## Done

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
