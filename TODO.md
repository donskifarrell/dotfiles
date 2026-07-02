# TODO

Repo task tracker. Each item should carry enough detail to hand off cold (to a person or a model). Migration
history/context lives in MIGRATION-STATUS.md; day-to-day conventions in CLAUDE.md.

## Open

### 1. Re-benchmark LLM backends after kernel 7.0 reboot

2026-07-03: `boot.kernelPackages = linuxPackages_latest` (7.0.12, newer amdgpu/KFD for RDNA4) staged with
`nixos-rebuild boot` — takes effect at next reboot. After rebooting:

- Re-run: `llama-bench-vulkan -m /var/lib/llm/models/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf -dev Vulkan0 -fa 1 -r 3` and
  the same with `llama-bench-rocm … -dev ROCm0`. Baselines on 6.18.35 (fa=1): vulkan pp512 3160 / tg128 108.6; rocm
  pp512 3284 / tg128 87.8. Update the header table in `modules/den/aspects/services/llm.nix` if numbers move.
- If anything regresses or misbehaves: revert the kernel commit (`git log --oneline -- modules/den/hosts/abhaile.nix`),
  rebuild, reboot — the previous generation is also in the boot menu.

### 2. Re-benchmark LLM backends after each `nix flake update`

RDNA4 (gfx1201) perf shifts with every llama.cpp/mesa/ROCm bump. Protocol + current numbers live in the
`modules/den/aspects/services/llm.nix` header; the winner is `services.llama-cpp.package` in the same file (currently
`llama-cpp-vulkan`; ROCm was already ahead on MoE prompt-processing, so the verdict may flip). Also re-check vLLM RDNA4
kernel support (vllm-project/vllm#28649) — if native gfx1201 kernels merge, vLLM becomes worth evaluating (it was
skipped 2026-07-03 because the gap was open).

### 3. Migrate services.llama-cpp to the `settings`-style module when inputs.nixpkgs catches up

NixOS modules come from `inputs.nixpkgs` (Den's own lock — no `follows`), packages from `nixpkgs-unstable` (FlakeHub
weekly). Newer nixpkgs replaced `services.llama-cpp.{model,extraFlags,host,port}` with a freeform `settings` attrset
(renames exist for model/host/port; `extraFlags` is **removed**). When `inputs.nixpkgs` updates past that change,
`modules/den/aspects/services/llm.nix` must move its flags into
`settings = { model = …; device = "Vulkan0"; n-gpu-layers = 99; flash-attn = "on"; ctx-size = 16384; jinja = true; }`.
Consider adding `den.inputs.nixpkgs.follows = "nixpkgs-unstable"` in `modules/flake-parts/flake-file.nix` to kill the
skew entirely (then `nix run .#write-flake`; check Den still evaluates).

### 4. Provision eachtrach (migration Phase 6)

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

### 5. Back up the sops editor identity

`~/.config/sops/age/keys.txt` is the only copy of the editing key (`&admin_df`). Losing it doesn't lose data (any
recipient host can decrypt: `ssh-to-age -private-key < /etc/ssh/ssh_host_ed25519_key` as root), but fix it properly:

- Either store an offline/paper backup of `keys.txt`, or
- generate a second admin age key kept offline, add it as a recipient in `.sops.yaml`, then
  `sops updatekeys secrets/*.yaml`.

### 6. (Optional) Rename clan-era secret names

`ssh/aon_clan` (+`_pub`) → post-clan name. Touches encrypted data, so do as its own change: `sops secrets/shared.yaml`
(rename keys) → update the `homeFiles` map in `secrets/home.nix` → update whatever references `~/.ssh/aon.clan` inside
the encrypted `sshconfig.local`. Verify with the eval-diff method from MIGRATION-STATUS.md / plan notes.

### 7. Restore per-host toplevel build checks

`nix flake check` currently runs only treefmt + check-flake-file — the old `checks.nix` (per-host
`nixosConfigurations.<h>.config.system.build.toplevel` as a check) was lost in the flake-parts cleanup. Re-add a
`modules/flake-parts/checks.nix` that maps every `nixosConfigurations.<host>` toplevel into
`checks.<system>.host-<host>` (guard cross-system hosts), so `nix flake check` catches config breakage again. Until
then, verify hosts with `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`.

### 8. Wire up (or delete) the delta/difftastic shell aspects

2026-07-02: `shell/delta.nix` + `shell/difftastic.nix` were dead `flake.homeModules` leftovers that broke
`nix flake check` (no `flake.homeModules` option exists since the HM flakeModule was removed); they're now proper Den
aspects (`den.aspects.shell.{delta,difftastic}.homeManager`) but **no bundle/host includes them**, so they're inert.
Either add them to `shell.bundles.base` / `dev.git` (verify the home-manager option names still exist when doing so —
they were never evaluated while dead) or delete them (the `dev.git` header claims they were merged there, but git.nix
contains no delta/difftastic config).

### 9. Port `nix-flake-install` from sini-nix

Excluded in `modules/flake-parts/pkgs.nix` because it needs:

- a port of sini-nix `pkgs/by-name/nix-flake-provision-keys` (key provisioning helper), and
- reworking its agenix-rekey workflow to this repo's sops-nix flow (host recipient = ssh-to-age of the target's host
  key; `sops updatekeys` instead of rekey).

Source: `/home/df/dev/sini-nix/pkgs/by-name/nix-flake-install/` (+ its `.sh`). Un-exclude in
`modules/flake-parts/pkgs.nix` once it builds.

## Done

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
  builds, `nix flake check` green (after fixing the pre-existing homeModules breakage, see item 8).
