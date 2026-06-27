# Migration status — Clan → Den + sops-nix + deploy-rs
Branch: migrate/off-clan   ·   Plan: clan-to-den-migration-prompt.md (the task prompt)   ·   Updated: 2026-06-27

## Resume here
Next action: Phase 1 — extract abhaile + shared secret plaintext via clan-cli into .migration-staging/plaintext/, write INVENTORY.md. (STOPPED at Phase B gate to report; awaiting go-ahead.)
Blocked on: user go-ahead to continue past Phase B gate. Phase 2 will additionally need the user's template bundle.

## Phases
- [x] 0  Branch + baseline            (0d6932b scaffolding; baseline built)
- [x] B  Bootloader pre-flight        (CONFIRMED: UEFI, grub→systemd-boot pending; see .migration-staging/bootloader.md)
- [ ] 1  Extract secrets (clan-cli)
- [ ] 2  sops-nix  (needs template files from user)
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
- Host-key materialization (the WRINKLE above): confirm the chosen approach — stage abhaile's current
  private host key and install it at /etc/ssh/ssh_host_ed25519_key before cutover so the age1ggl…
  identity is preserved. (Needs a sudo/root step on abhaile.)
- Phase 2 template bundle: when ready, paste/attach .sops.yaml + the Den secrets aspects +
  rewritten secrets-user.nix + SECRETS-MIGRATION.md.
- Does the user want `try` migrated too, or only abhaile? (Plan focuses on abhaile; try is a test host.)

## Log
- 2026-06-27 · phase 0 · created branch migrate/off-clan, gitignored .migration-staging/, wrote tracker · 0d6932b
- 2026-06-27 · phase 0 · baseline build OK = /nix/store/vm0m0znxxly1fg3yh1igbchj3k69vcvg-nixos-system-abhaile-26.11.20260531.331800d (saved to .migration-staging/baseline-abhaile + /tmp/baseline-abhaile)
- 2026-06-27 · phase B · recorded bootloader state; UEFI + grub-via-removable-fallback, systemd-boot not yet installed; ESP 60% full · see .migration-staging/bootloader.md
- 2026-06-27 · STOPPED at Phase B gate to report before continuing.

## Final hand-off notes (fill during Phase 7)
- Deploy commands · rollback per host · where the host age identity comes from
