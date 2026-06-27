# Migration status — Clan → Den + sops-nix + deploy-rs
Branch: migrate/off-clan   ·   Plan: clan-to-den-migration-prompt.md (the task prompt)   ·   Updated: 2026-06-27

## Resume here
Next action: Phase 2 — apply the user's template bundle, then populate+encrypt secrets/{shared,abhaile}.yaml from .migration-staging/plaintext per the decided secret set, wire aspects, round-trip verify, `nix flake check`.
Blocked on: WAITING for the user to PASTE the Phase-2 template bundle (.sops.yaml + modules/den/aspects/secrets/{sops,abhaile}.nix + rewritten modules/system/secrets-user.nix + SECRETS-MIGRATION.md). User confirmed they have it.

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

## Final hand-off notes (fill during Phase 7)
- Deploy commands · rollback per host · where the host age identity comes from
