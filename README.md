# dotfiles

NixOS configuration on a **dendritic** [flake-parts](https://flake.parts) flake:

- **[Den](https://github.com/denful/den)** builds the `nixosConfigurations` from bottom-up, feature-based _aspects_
  composed into _roles_ and per-host configs (importing a module activates it — no `enable` flags).
- **[sops-nix](https://github.com/Mic92/sops-nix)** manages secrets; each host decrypts with its own SSH host key.
- **[deploy-rs](https://github.com/serokell/deploy-rs)** for remote day-2 deploys, **nixos-anywhere** for provisioning
  new hosts.

Configs borrow heavily from [onix-core](https://github.com/onixcomputer/onix-core) and
[perstarkse/infra](https://github.com/perstarkse/infra). (Previously orchestrated with Clan; migrated off — see
`MIGRATION-STATUS.md`.)

## Machines

| Host      | System       | What                                                             |
| --------- | ------------ | ---------------------------------------------------------------- |
| abhaile   | x86_64-linux | df's AMD desktop workstation (LUKS root, systemd-boot)           |
| eachtrach | x86_64-linux | Hetzner VPS, tailscale exit node — disposable, reprovision fresh |

## Layout

```
modules/den/        the config: den.nix, hosts/<host>.nix, aspects/, roles/, users/
hosts/<host>/       per-machine disko.nix + facter.json (imported by the den host)
secrets/*.yaml      sops-encrypted secrets (shared.yaml, <host>.yaml)
.sops.yaml          sops recipients / creation rules
```

## Common commands

```bash
# Build + activate the local machine
sudo nixos-rebuild switch --flake .#abhaile

# Validate (eval + per-host build + treefmt) and format
nix flake check
nix fmt

# Update inputs (keep as its own commit)
nix flake update

# Remote day-2 deploy (once a deploy node is wired in)
nix develop -c deploy .#<host>

# Provision a fresh host
nix develop -c nixos-anywhere --flake .#<host> root@<ip>

# Edit secrets (decrypts with ~/.config/sops/age/keys.txt)
nix develop -c sops secrets/shared.yaml
```

## Secrets

The host identity is its SSH host key (`/etc/ssh/ssh_host_ed25519_key`); its sops recipient is
`ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`. To add a new host as a recipient, put its age key in `.sops.yaml` and
run `sops updatekeys secrets/<file>.yaml`. The dev shell (`nix develop`) provides `sops`, `ssh-to-age`, `age`,
`deploy-rs`, and `nixos-anywhere`.
