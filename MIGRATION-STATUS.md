# Migration status — Clan → Den + sops-nix + deploy-rs
Branch: migrate/off-clan   ·   Plan: clan-to-den-migration-prompt.md (the task prompt)   ·   Updated: 2026-06-27

## Resume here
Next action: Phase 2 — stand up sops-nix. FIRST ask the user for the prepared template bundle (.sops.yaml + Den secrets aspects + rewritten secrets-user.nix + SECRETS-MIGRATION.md). STOPPED at Phase 1 gate to report.
Blocked on: user must (a) confirm Phase-1 inventory + the Section-C decisions, (b) provide the Phase-2 template bundle.

## Phases
- [x] 0  Branch + baseline            (0d6932b scaffolding; baseline built)
- [x] B  Bootloader pre-flight        (1c0fb20; CONFIRMED UEFI, grub→systemd-boot pending; .migration-staging/bootloader.md)
- [x] 1  Extract secrets (clan-cli)   (secrets staged: 36/36 OK; .migration-staging/INVENTORY.md)
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
- DECIDED: abhaile only (try left on clan / disposable). [2026-06-27]
- Host-key materialization (the WRINKLE above): confirm approach — install abhaile's staged private host
  key at /etc/ssh/ssh_host_ed25519_key{,.pub} before cutover so the age1ggl… identity is preserved.
  (Needs a sudo/root step on abhaile.) Staged at .migration-staging/plaintext/abhaile/openssh/.
- Phase 2 template bundle: when ready, paste/attach .sops.yaml + Den secrets aspects + rewritten
  secrets-user.nix + SECRETS-MIGRATION.md.
- From Phase-1 INVENTORY Section C — confirm dispositions:
  - Tailscale on abhaile? (currently dropped in flake; live gen logged out). Re-add aspect + mint fresh key?
  - Re-enable the ~/.ssh + ~/.config/git home secrets (secrets-user.nix is currently orphaned)?
  - root password: keep root key-only, or migrate the staged root hash?
  - emergency-access: replicate or drop?
  - HostCertificate / openssh-ca: keep host cert (public) or drop?

## Log
- 2026-06-27 · phase 0 · created branch migrate/off-clan, gitignored .migration-staging/, wrote tracker · 0d6932b
- 2026-06-27 · phase 0 · baseline build OK = /nix/store/vm0m0znxxly1fg3yh1igbchj3k69vcvg-nixos-system-abhaile-26.11.20260531.331800d (saved to .migration-staging/baseline-abhaile + /tmp/baseline-abhaile)
- 2026-06-27 · phase B · recorded bootloader state; UEFI + grub-via-removable-fallback, systemd-boot not yet installed; ESP 60% full · see .migration-staging/bootloader.md
- 2026-06-27 · STOPPED at Phase B gate; user approved continue, scope = abhaile only.
- 2026-06-27 · phase 1 · staged 36/36 secrets+values for abhaile+shared via sops -d (df key); host key→age1ggl… verified; df hash valid $6$; built-config consumes only host key + df password (+ public host cert). INVENTORY.md written. STOPPED at Phase 1 gate to report.

## Final hand-off notes (fill during Phase 7)
- Deploy commands · rollback per host · where the host age identity comes from
