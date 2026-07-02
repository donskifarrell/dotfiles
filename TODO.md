# TODO

Repo task tracker. Each item should carry enough detail to hand off cold (to a person or a model). Migration
history/context lives in MIGRATION-STATUS.md; day-to-day conventions in CLAUDE.md.

## Open

### 1. Switch abhaile onto the simplified secrets plumbing

The 2026-07-02 secrets refactor (single-map `secrets/home.nix`, secrets declared next to consumers, no `secrets` group)
is **build-verified only** — the live system still runs the old generation.

- Run: `sudo nixos-rebuild switch --flake .#abhaile`
- Expected activation diff (all intentional):
  - home secrets under `/run/secrets/*` change owner `root:secrets` → `df:users`; private ssh keys 0640 → 0600,
    sshconfig.local 0640 → 0600.
  - the `secrets` group disappears; df's membership in it disappears.
  - `~/.ssh` / `~/.config/git` dir group `secrets` → `users` (tmpfiles adjusts in place).
  - symlink targets/dests are byte-identical to before (verified by eval diff pre/post refactor).
- Smoke test after switch: `ssh -T git@github.com` (uses `~/.ssh/df_gh` via `sshconfig.local`),
  `git config --get user.email` in a repo using an included gitconfig, `systemctl status tailscaled`.

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

### 7. Port `nix-flake-install` from sini-nix

Excluded in `modules/flake-parts/pkgs.nix` because it needs:

- a port of sini-nix `pkgs/by-name/nix-flake-provision-keys` (key provisioning helper), and
- reworking its agenix-rekey workflow to this repo's sops-nix flow (host recipient = ssh-to-age of the target's host
  key; `sops updatekeys` instead of rekey).

Source: `/home/df/dev/sini-nix/pkgs/by-name/nix-flake-install/` (+ its `.sh`). Un-exclude in
`modules/flake-parts/pkgs.nix` once it builds.

## Done

- 2026-07-02 — Secrets review: decided to **stay on sops-nix** (over agenix/agenix-rekey; identical age identity model,
  working setup, `neededForUsers` + multi-secret YAML in use). Simplified plumbing: base wiring aspect, single-map
  `secrets/home.nix` (was 3 declarations per secret across 2–3 files), tailscale secret moved next to its consumer,
  `secretsUser.enable` flag removed (dendritic), stale docs fixed, ssh-to-age/age added to devshell. Verified: eval-diff
  of `sops.secrets` + tmpfiles vs pre-refactor baseline (only intended owner/group/mode deltas), abhaile toplevel
  builds, `nix flake check` green (after fixing the pre-existing homeModules breakage, see item 6).
