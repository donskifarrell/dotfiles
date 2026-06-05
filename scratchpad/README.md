# Den MVP scratchpad — `short` + `df`

A throwaway, self-contained Den flake implementing **PLAN.md step 1.3**: one machine
(`short`) with one user (`df`), composed from a minimal set of Den aspects. Validated against
the **real upstream** `github:denful/den` API (not sini-nix's feature-branch schema).

## Layout (mirrors the plan's "Repository layout")

```
flake.nix                          flake-parts + import-tree ./modules + den input
modules/den/
  den.nix                          imports den.flakeModule; den.default (stateVersion, hostname,
                                   define-user); enables home-manager for all users
  aspects/core/
    nix.nix                        nix settings, gc, trusted-users   (← modules/system/nix-config.nix)
    i18n.nix                       en_GB locale + timezone + keymap   (← i18n.nix / keyboard.nix)
    openssh.nix                    sshd + ssh-agent                   (← openssh.nix)
    networking.nix                 NetworkManager                     (← networking.nix)
    shell.nix                      fish system-wide
    facter.nix                     imports nixos-facter-modules       (reusable)
    disko.nix                      imports disko module               (reusable)
  aspects/roles/
    server.nix                     role-server = includes the core.* aspects
  hosts/short.nix                  den.hosts.…short.users.df + den.aspects.short (role +
                                   hardware aspects + facter report path + disk layout)
  hosts/short.facter.json          hardware report (← machines/short/facter.json; .json so
                                   import-tree ignores it)
  users/df.nix                     den.aspects.df (primary-user, fish, ssh key, HM git)
```

## How Den is wired (upstream API, verified)

- **Host + its users:** `den.hosts.x86_64-linux.short.users.df = { }`.
- **Host aspect** (auto-applied to `short`): `den.aspects.short` — `includes` the role + a
  `nixos` block for host-only bits.
- **User aspect** (auto-applied to `df`): `den.aspects.df` — `includes` batteries
  (`den.batteries.primary-user`, `den.batteries.user-shell "fish"`) + `nixos`/`homeManager` blocks.
- **Batteries** in `den.default.includes`: `den.batteries.hostname`, `den.batteries.define-user`.
- **HM for all users:** `den.schema.user.classes = lib.mkDefault [ "homeManager" ]`.

## Validate

The scratchpad lives inside the `.dotfiles` git repo, so Nix won't see these files until they're
tracked. Either copy out, or intent-to-add:

```bash
# Option A — copy to a temp git repo and check there (non-invasive)
TMP=$(mktemp -d); cp -r . "$TMP"; cd "$TMP"; git init -q && git add -A && git commit -qm x
nix flake show
nix eval .#nixosConfigurations.short.config.users.users.df.extraGroups
nix build --dry-run .#nixosConfigurations.short.config.system.build.toplevel

# Option B — from this dir, make files visible without committing content
git add -N .
nix flake show
```

Confirmed evaluating: hostname=short, locale=en_GB, sshd on, NetworkManager on, fish on,
`df` is a normal user in `wheel`+`networkmanager` with fish shell + authorized key, root key
present, HM git configured, `system.stateVersion = 25.11`. **Hardware is real now**: facter
populates `boot.initrd.availableKernelModules` (nvme, virtio_blk, …) and disko produces an `ext4`
root on a `by-partlabel` device + `vfat` `/boot` with grub/EFI. `nix build --dry-run` of the
toplevel resolves the full closure with no eval errors.

## Spin up a throwaway VM and boot this config

`nixos-rebuild build-vm` turns `nixosConfigurations.short` into a QEMU VM. The VM-only login
(`aspects/core/vm-login.nix`, under `virtualisation.vmVariant`) gives autologin + creds so it's
usable; it does **not** affect real deploys. Disko does **not** repartition anything — the VM
variant overrides `fileSystems` and boots off an ephemeral `./short.qcow2`.

```bash
# Build from a copy outside the .dotfiles git tree (non-invasive — Nix can't see
# untracked files inside the parent repo). Alternatively: `git add scratchpad`.
cp -r /home/df/.dotfiles/scratchpad /tmp/short-vm && cd /tmp/short-vm

nixos-rebuild build-vm --flake .#short   # first build pulls the full closure — slow
./result/bin/run-short-vm                # boots QEMU; console autologins as df
```

- **SSH in:** `ssh -p 2222 df@localhost` (password `df`; root password `root`).
- **Quit QEMU:** `poweroff` inside, or `Ctrl-a x` in the terminal.
- **Reset disk state:** delete `./short.qcow2` between runs.

(Alternative — deploy onto the _existing_ libvirt `short` VM, whose facter/disko this matches:
`nixos-rebuild switch --flake .#short --target-host root@192.168.122.217`. This bypasses clan,
so prefer `build-vm` while iterating.)

## Known stubs / TODO before this is real

- **Disk layout in `hosts/short.nix` is lifted verbatim from `machines/short/disko.nix`** (and the
  facter report is copied from `machines/short/facter.json`). Re-sync if clan regenerates them.
- **SSH key** is the one lifted from `machines/short`; swap for the clan-managed key.
- No secrets/clan integration yet — that's later plan phases. This proves the Den composition only.
- `trusted-users` lists `root` explicitly (NixOS already trusts root) — harmless duplicate.

## Next iterations (from this spine)

Add one concern at a time as a new leaf under `aspects/<cat>/` that a role `includes`
(plan Phase 2): `security` (sudo/hardening), `tailscale`, `dev-tools`, then port `abhaile`'s
desktop aspects — all VM-validated before touching the real desktop (plan 6.6).

## Aspects

The `machines/` + `modules/` of the main dotfiles have been ported into Den aspects
under `aspects/`. Each leaf is `den.aspects.<cat>.<name>.{nixos,homeManager}`; importing
activates nothing on its own — a **role** (or host) `includes` the leaves it wants.

### Roles (`aspects/roles/`)

| Role          | Includes                                                                                              | Wired to a host?                |
| ------------- | ----------------------------------------------------------------------------------------------------- | ------------------------------- |
| `server`      | `core.{nix,i18n,openssh,networking,shell,vm-login}`                                                    | **Yes** — `short`               |
| `workstation` | server-ish base + shell/dev/cli home apps (fish, ghostty, git, neovim, ssh, direnv, cli, xdg, packages) | No (building block)             |
| `desktop`     | `workstation` + GNOME, AMD cpu/gpu, sound, bluetooth, printing, libvirt, gaming, vscode/claude, productivity apps, package toggles | No — abhaile target (plan 6.6) |

### Concern leaves

- **`core/`** — `nix`, `i18n`, `openssh`, `networking`, `shell`, `nh`, `bootlabel`, `facter`, `disko`, `vm-login`
- **`desktop/`** — `gnome`, `cosmic`, `fonts`, `keyboard` (xkb), `sound`, `printing`, `touchpad`, `flatpak`, `appimage`, `udisks2`
- **`hardware/`** — `cpu/amd`, `gpu/amd`, `bluetooth`, `ledger`, `tweaks`
- **`security/`** — `opensnitch`
- **`services/`** — `web/caddy`, `networking/avahi`, `storage/paperless`
- **`virtualization/`** — `libvirt`
- **`apps/`** (home-manager) — `shell/{fish,atuin,eza,starship,yazi,zellij,zoxide}`, `terminals/ghostty`,
  `dev/{git,direnv,distrobox,neovim,ssh,vscode,claude}`, `gaming/{steam,alvr}`, `productivity/apps`,
  `desktop/tray`, `cli`, `xdg`, `packages`

### Not yet ported (intentionally)

- **Secrets** (`modules/system/secrets-sops.nix`, `secrets-user.nix`) — clan-vars + agenix work, deferred to
  PLAN phase 2.3. They need the `clan-core` input, which this scratchpad doesn't carry.
- **`nix-virt.nix`** — declarative libvirt domains reference `config.clan.machines.*` (clan-coupled) and the
  `NixVirt` input; left for when clan is wired in. `virtualization/libvirt` covers the libvirtd host itself.
- **`my.mainUser`/`my.flakeHostname` options** (`options.nix`) — superseded by Den's host/user schema.

### Inputs added for the ported aspects

`flake.nix` gained `nix-vscode-extensions` (vscode marketplace overlay) and `claude-code`. Both are only
forced when a host includes `apps.dev.vscode` / `apps.dev.claude`; the server `short` build stays lazy.
