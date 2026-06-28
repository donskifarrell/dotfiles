# CLAUDE.md

Guidance for Claude Code working in this repo.

## Stack

NixOS dotfiles on a **dendritic** flake-parts flake. Configs are built by **[Den](https://github.com/denful/den)**
(bottom-up, feature-based aspects), secrets by **sops-nix**, day-2 remote deploys by **deploy-rs**, and new-host
provisioning by **nixos-anywhere**. (Clan was the previous orchestrator; it has been removed.)

Dendritic principle: **importing a module activates it** — no `enable` flags. Compose reusable *aspects* into
*roles*, then into per-host configs. Every file under `./modules` is auto-imported (`import-tree`).

## Repo layout

```
flake.nix              flake-parts; imports home-manager + treefmt + (import-tree ./modules)
modules/den/           the whole config (auto-imported)
  den.nix              wires inputs.den.flakeModule
  hosts/<host>.nix     emits nixosConfigurations.<host> (composes aspects + machine data)
  aspects/             feature modules by category: core, hardware, shell, dev,
                       services, secrets, apps, gaming, virtualisation
  roles/               aspect bundles: default, workstation, dev, desktop
  users/df.nix         the df user aspect (home-manager)
hosts/<host>/          machine data imported by that host: disko.nix + facter.json
secrets/*.yaml         sops-nix encrypted secrets (shared.yaml = multi-host, <host>.yaml = per-host)
.sops.yaml             sops recipients + creation rules
```

An aspect is `den.aspects.<path>.{nixos|homeManager|darwin} = <module>`; reference it in an `includes` list as
`<path>` (e.g. `core.network.openssh`). Files/dirs prefixed `_` are excluded from auto-import.

## Machines

| Host | System | Role |
|------|--------|------|
| abhaile | x86_64-linux | df's AMD desktop workstation (LUKS root, systemd-boot) |
| eachtrach | x86_64-linux | Hetzner VPS, tailscale exit node — disposable, reprovision fresh |

## Common commands

```bash
nixos-rebuild switch --flake .#abhaile      # build + activate locally (nh also configured)
nix flake check                              # eval + per-host toplevel build + treefmt
nix fmt                                       # nixfmt + statix + deadnix (treefmt)
nix flake update                              # update inputs (commit flake.lock on its own)
deploy .#<host>                               # deploy-rs remote day-2 (once a deploy node is wired)
nixos-anywhere --flake .#<host> root@<ip>     # provision a new host
```

## Secrets (sops-nix)

- Edit:  `sops secrets/shared.yaml` / `sops secrets/abhaile.yaml` — decrypts with the df age key at
  `~/.config/sops/age/keys.txt` (recipient `age1awmgr…`).
- Each host decrypts with its **own SSH host key**: `sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]`;
  its recipient is `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`.
- New host: add its ssh-to-age recipient to `.sops.yaml`, then `sops updatekeys secrets/<file>.yaml`.
- Password hashes use `neededForUsers = true`; home ssh/git files are symlinked by the `secrets.user` aspect.

## Conventions

- treefmt: `nix flake check` runs a strict nixfmt; if `nix fmt` leaves `_:\n{}` expanded, hand-collapse to
  `_: {}` (what the check wants) and re-run `nix fmt`.
- Keep `nix flake update` as its own commit so it can be reverted independently.
