# Migration status — Clan → Den + sops-nix + deploy-rs
Branch: migrate/off-clan   ·   Plan: clan-to-den-migration-prompt.md (the task prompt)   ·   Updated: 2026-06-27

## Resume here
Next action: Phase 3 — make Den the SOLE builder of nixosConfigurations.abhaile (flip intoAttr, import machine dir, drop clan injection), THEN wire the consumers conflict-free: df/root hashedPasswordFile -> sops secrets, secretsUser.enable + import secrets-user, include services.tailscale, boot.initrd.systemd.emergencyAccess literal, nix substituters. Build + closure-diff.
Blocked on: nothing. (Phase 3 also needs the host-key install at /etc/ssh/ssh_host_ed25519_key before any SWITCH — a sudo step for the user, but NOT before build/diff.)

## Phase 2 facts (verified, don't re-derive)
- inputs.sops-nix == clan-core.inputs.sops-nix → SAME store path (/nix/store/xkbln7rg…). Importing
  sops-nix.nixosModules.sops dedupes with clan's; NO double-declaration conflict while clan still builds.
- abhaile boot.initrd.systemd.enable = true (systemd-initrd) → emergency-access = one-liner
  `boot.initrd.systemd.emergencyAccess = "<$6$ hash>"` (literal; option takes a string, not a file).
- abhaile: LUKS device "cryptroot"; root has NO hashedPasswordFile today (key-only); df hashedPasswordFile
  = clan path. systemd-boot declared (grub.enable=false in new cfg).
- try.nix includes roles.default → DO NOT put secrets.sops in roles.default (would hit try, which is not a
  .sops.yaml recipient). Scope secrets.sops/secrets.abhaile to the abhaile HOST includes instead.
- clan's user-df sets df.hashedPasswordFile on abhaile → overriding it needs lib.mkForce during the
  clan+den transition (Phase 2–4). Drops out naturally once Den is the sole builder (Phase 3).
- No NixOS tailscale aspect exists yet (services/tailscale.nix is homeModule-only). Build the de-clanned
  NixOS aspect; inline host-sync from services/tailscale/host-sync.nix.
- secrets-sops.nix (clan ssh/git generators) is imported NOWHERE → dormant; safe to delete.
- FLAKES GOTCHA: new untracked files are invisible to `nixos-rebuild --flake` (evaluates the git
  tree). Always `git add` new aspect/secret files before building or den.aspects.<new> is undefined.

## Decisions locked (2026-06-27)
- Scope: abhaile only (try stays on clan / disposable).
- sops-nix secret set for abhaile = host key + df password (mandatory) + ~/.ssh & ~/.config/git home
  secrets (re-enable secrets-user.nix) + root password + emergency-access. (Syncthing deferred.)
- Tailscale: RE-ADD as a Den aspect on abhaile + mint a FRESH auth key (staged keys ~6mo old, expired).
- Templates: user will paste the bundle (do not author from scratch).

## Phases
- [x] 0  Branch + baseline            (0d6932b scaffolding; baseline built)
- [x] B  Bootloader pre-flight        (1c0fb20; CONFIRMED UEFI, grub→systemd-boot pending; .migration-staging/bootloader.md)
- [x] 1  Extract secrets (clan-cli)   (secrets staged: 36/36 OK; .migration-staging/INVENTORY.md)
- [x] 2  sops-nix  (templates applied; secrets encrypted; flake check green — Phase 2 commit below)
- [ ] 3  Den builds nixosConfigurations
- [ ] 4  Build + closure diff
- [ ] 5  Cut over abhaile
- [ ] 5b Flake update (separate)
- [ ] 6  Fresh eachtrach (nixos-anywhere)
- [ ] 7  Remove Clan + doc cleanup
- [ ] 8  (optional) agenix
Mark each `[x]` with its commit sha when done.

## Key facts (don't re-derive)
- Running ON abhaile as user `df`. sudo needs a password (non-interactive sudo unavailable to the agent).
- df admin recipient = age1awmgrhav72rx0dluch3ztj0ku6xkrg2utnrkva2qhm8sdw76sf7qqc9c5t
  — CONFIRMED == age pubkey of local ~/.config/sops/age/keys.txt.
- abhaile HOST-KEY → age recipient (the sops-nix identity going forward)
  = age1gglfnksmkvjlvnzunt6lmvzngam66cpwrek73t3dnn5l05qlq3ls4pcjdn
  (this is ssh-to-age of vars/per-machine/abhaile/openssh/ssh.id_ed25519.pub; matches plan's age1ggl…)
- LEGACY clan per-machine age key (to be retired) = age1z89sqxets0lhujdgpq96nxwpj3pzkqj64rsywssz9wg2kwpyme4syaxx26
  (stored in sops/machines/abhaile/key.json; NOT the host-key identity).
- WRINKLE (Phase 2/3): abhaile's sshd HostKey is currently /run/secrets/vars/openssh/ssh.id_ed25519
  (clan-managed), NOT /etc/ssh/ssh_host_ed25519_key. The same private key must be materialized at the
  standard path before/at cutover, or the host age identity (age1ggl…) won't survive clan removal and
  sops-nix won't be able to decrypt. Plan: stage the private host key in Phase 1; install it at
  /etc/ssh/ssh_host_ed25519_key{,.pub} as a one-time persistent step before the Phase 5 switch.
- Secrets backend target: sops-nix; host identity = /etc/ssh/ssh_host_ed25519_key.
- eachtrach: DISPOSABLE — secrets dropped, reprovision fresh in Phase 6.
- Bootloader: UEFI confirmed; grub→systemd-boot transition happens on first abhaile switch (Phase 5).

## Open questions for the user
- Host-key materialization (the WRINKLE): install abhaile's staged private host key at
  /etc/ssh/ssh_host_ed25519_key{,.pub} before cutover so the age1ggl… identity is preserved.
  Needs a sudo/root step on abhaile; staged at .migration-staging/plaintext/abhaile/openssh/. Confirm
  timing in Phase 3/5. (Agent has no non-interactive sudo — user runs this step.)
- HostCertificate / openssh-ca: keep the host cert (public) or drop? Default plan = drop for abhaile-only
  unless user objects (no secret risk either way).

## Log
- 2026-06-27 · phase 0 · created branch migrate/off-clan, gitignored .migration-staging/, wrote tracker · 0d6932b
- 2026-06-27 · phase 0 · baseline build OK = /nix/store/vm0m0znxxly1fg3yh1igbchj3k69vcvg-nixos-system-abhaile-26.11.20260531.331800d (saved to .migration-staging/baseline-abhaile + /tmp/baseline-abhaile)
- 2026-06-27 · phase B · recorded bootloader state; UEFI + grub-via-removable-fallback, systemd-boot not yet installed; ESP 60% full · see .migration-staging/bootloader.md
- 2026-06-27 · STOPPED at Phase B gate; user approved continue, scope = abhaile only.
- 2026-06-27 · phase 1 · staged 36/36 secrets+values for abhaile+shared via sops -d (df key); host key→age1ggl… verified; df hash valid $6$; built-config consumes only host key + df password (+ public host cert). INVENTORY.md written. STOPPED at Phase 1 gate to report.
- 2026-06-27 · phase 2 · applied template bundle (.sops.yaml + secrets aspects + secrets-user.nix); built+encrypted secrets/{shared,abhaile}.yaml (17+2 secrets, recipients admin_df+host_abhaile, round-trip verified; ssh privkeys parse, ff/uf passphrase-protected); deleted clan secrets-sops.nix; created de-clanned tailscale NixOS aspect; included secrets.sops+secrets.abhaile on abhaile (declaration-only, consumer wiring deferred to Phase 3). abhaile builds (h9ckq8h…); manifests list all new secrets. `nix flake check` GREEN after a separate hygiene commit (ce896a9) fixed pre-existing treefmt. Phase 2 commit next.
- NOTE: treefmt wrapper (`nix fmt`) is lenient (leaves `_:\n{}` expanded) but the flake's treefmt-CHECK is strict (wants `_: {}` collapsed). Hand-collapse the lambda + `nix fmt`; the collapsed form survives. The repo was treefmt-dirty on baseline (pre-commit is disabled in flake.nix).

## Final hand-off notes (fill during Phase 7)
- Deploy commands · rollback per host · where the host age identity comes from
