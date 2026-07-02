# CLAUDE.md

Guidance for Claude Code working in this repo.

## Stack

NixOS dotfiles on a **dendritic** flake-parts flake. Configs are built by **[Den](https://github.com/denful/den)**
(bottom-up, feature-based aspects), secrets by **sops-nix**, day-2 remote deploys by **deploy-rs**, and new-host
provisioning by **nixos-anywhere**. (Clan was the previous orchestrator; it has been removed.)

Dendritic principle: **importing a module activates it** — no `enable` flags. Compose reusable _aspects_ into _roles_,
then into per-host configs. Every file under `./modules` is auto-imported (`import-tree`).

## Repo layout

```
flake.nix              just description + inputs + `mkFlake { imports = [ (import-tree ./modules) ]; }`
modules/                everything else, auto-imported as flake-parts modules
  flake-parts/          the flake's own plumbing (NOT Den config): flake-file.nix (inputs →
                          `nix run .#write-flake` regenerates flake.nix), devshell.nix, treefmt.nix,
                          pre-commit.nix, pkgs.nix (auto-wires pkgs/by-name), den-tree.nix
  den/                  the whole NixOS/HM config Den builds:
    den.nix              wires inputs.den.flakeModule
    hosts/<host>.nix     emits nixosConfigurations.<host> (composes aspects + machine data)
    aspects/             feature modules by category: core, hardware, shell, dev,
                         services, secrets, apps, gaming, virtualisation
    roles/               aspect bundles: default, workstation, dev, desktop
    users/df.nix         the df user aspect (home-manager)
hosts/<host>/          machine data imported by that host: disko.nix + facter.json
secrets/*.yaml         sops-nix encrypted secrets (shared.yaml = multi-host, <host>.yaml = per-host)
.sops.yaml             sops recipients + creation rules
.mcp.json              Claude Code MCP servers for this repo (nixos = mcp-nixos via `nix run`)
```

An aspect is `den.aspects.<path>.{nixos|homeManager|darwin} = <module>`; reference it in an `includes` list as `<path>`
(e.g. `core.network.openssh`). Files/dirs prefixed `_` are excluded from auto-import.

## Machines

| Host      | System       | Role                                                             |
| --------- | ------------ | ---------------------------------------------------------------- |
| abhaile   | x86_64-linux | df's AMD desktop workstation (LUKS root, systemd-boot)           |
| eachtrach | x86_64-linux | Hetzner VPS, tailscale exit node — disposable, reprovision fresh |

## Common commands

```bash
nixos-rebuild switch --flake .#abhaile      # build + activate locally (nh also configured)
nix flake check                              # treefmt + flake-file check ONLY (per-host toplevel
                                             #   checks were lost in cleanup — see TODO.md); to
                                             #   really verify a host, build its toplevel:
nix build .#nixosConfigurations.abhaile.config.system.build.toplevel
nix fmt                                       # nixfmt + statix + deadnix (treefmt)
nix flake update                              # update inputs (commit flake.lock on its own)
deploy .#<host>                               # deploy-rs remote day-2 (once a deploy node is wired)
nixos-anywhere --flake .#<host> root@<ip>     # provision a new host
```

## Secrets (sops-nix)

Layout — secrets are declared **next to their consumers**; the base aspect is wiring only:

- `modules/den/aspects/secrets/sops.nix` — base aspect: imports sops-nix + sets the decryption identity. No secrets.
  Include it on every host that consumes any secret.
- `modules/den/aspects/secrets/home.nix` — df's home ssh/git files, **one map line per secret** (yaml key → `$HOME`
  dest); sops.secrets entries, modes, owner and symlinks are all derived from that map.
- `modules/den/aspects/secrets/<host>.nix` — host-only secrets (e.g. abhaile password hashes).
- Service secrets live in the service's own aspect (e.g. `services/tailscale.nix` declares its authkey).

Identities:

- Editing: df's age key at `~/.config/sops/age/keys.txt` (recipient `&admin_df` in `.sops.yaml`). Edit with
  `sops secrets/shared.yaml` / `sops secrets/abhaile.yaml`.
- Each host decrypts with its **own SSH host key**: `sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]`; its
  recipient is `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub` (ssh-to-age + age are in the devshell).
- **Recovery**: if the editor key is lost, any recipient host can still produce a working identity:
  `ssh-to-age -private-key < /etc/ssh/ssh_host_ed25519_key` (run as root on that host).

Recipes:

- **Add a home secret** (2 steps): add the key/value via `sops secrets/shared.yaml`, then one line in the `homeFiles`
  map in `secrets/home.nix`. Derivation: `/run/secrets` name = key with `/`→`-`; `ssh/*` without `_pub` → mode 0600,
  else 0644; owner df.
- **Add a service secret**: declare `sops.secrets.<name> = { sopsFile; key; … }` in the consuming aspect.
- **Add a host**: `ssh-to-age` its host key → add recipient + (if per-host secrets) creation rule to `.sops.yaml` →
  `sops updatekeys secrets/<file>.yaml` for every file it must read → include `secrets.sops` in the host.

Gotchas (easy to forget):

- Password hashes need `neededForUsers = true` (decrypted early to `/run/secrets-for-users`; owner/mode forced to root).
- `boot.initrd.systemd.emergencyAccess` takes a **literal hash string** baked into the initrd — it cannot be a sops path
  (lives in `hosts/abhaile.nix`).
- NEVER manage a host's own `/etc/ssh/ssh_host_ed25519_key` via sops — it's the key sops-nix decrypts with.
- Tailscale auth keys expire (~90d). Already-joined nodes stay connected; mint a fresh key only for new joins.
- Flakes gotcha: `git add` new files before building/evaluating, or the flake won't see them.

## Conventions

- treefmt: `nix flake check` runs a strict nixfmt; if `nix fmt` leaves `_:\n{}` expanded, hand-collapse to `_: {}` (what
  the check wants) and re-run `nix fmt`.
- Keep `nix flake update` as its own commit so it can be reverted independently.
