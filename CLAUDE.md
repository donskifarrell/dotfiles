# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

NixOS dotfiles repository using [Clan.lol](https://clan.lol) as an orchestrator and [flake-parts](https://flake.parts) for modular flake structure. Follows the **dendritic design pattern** for bottom-up, feature-based configuration.

**References:**
- Dendritic Design Guide: https://github.com/Doc-Steve/dendritic-design-with-flake-parts
- Flake-parts: https://flake.parts

## Common Commands

```bash
# Rebuild local machine (uses nh which is configured in modules)
nh os switch .#<hostname>

# Deploy to remote machine
clan machines install <machine> --target-host root@<ip>

# Update the flake
nix flake update

# Format all nix files (uses treefmt with nixfmt, statix, deadnix)
nix fmt

# Enter dev shell with clan-cli and formatters
nix develop
```

## Machines

| Hostname | User | System | Role |
|----------|------|--------|------|
| [abhaile](machines/abhaile/README.md) | df | x86_64-linux | Desktop workstation |
| eachtrach | mise | x86_64-linux | VPS (frozen - exit node) |
| short | mise | x86_64-linux | Test VM → service host |
| nas-storage | tbd | x86_64-linux | Future - backup storage |

## Architecture

### Dendritic Design Pattern

This repo follows a **bottom-up, feature-based** approach rather than top-down host assignment. Features are reusable units that can be applied across different configuration contexts (NixOS, Home-Manager, Darwin).

Key principles:
- **Features over hosts** - Create reusable features, then compose them per-machine
- **Importing activates** - No `enable = true` flags; importing a module activates it
- **Context separation** - Each feature defines aspects for relevant contexts (nixos, homeManager)

### Dendritic Aspects (Design Patterns)

When creating or modifying features, consider which patterns apply:

| Aspect | Use When |
|--------|----------|
| **Simple** | Feature works independently across contexts without dependencies |
| **Multi-Context** | Main context (NixOS) needs mandatory nested context config (Home-Manager) |
| **Inheritance** | Extending or modifying an existing parent feature |
| **Conditional** | Different behavior needed per system type (Linux vs Darwin) |
| **Collector** | Gathering config contributions from multiple features (e.g., syncthing peers) |
| **Constants** | Sharing values/functions across multiple features |
| **DRY** | Reusable components for repeated attribute patterns |
| **Factory** | Parameterized features generating multiple variants |

### Flake-Parts Module Structure

Modules are auto-imported via `import-tree` and exposed under `config.flake`:

```nix
# Module classes used in this repo:
config.flake.nixosModules.<name>   # NixOS system modules
config.flake.homeModules.<name>    # Home-manager modules
```

Standard module file pattern:
```nix
{
  config.flake.nixosModules.featurename = { lib, pkgs, config, ... }: {
    # Feature implementation for NixOS context
  };
}
```

For multi-context features, define aspects for each context in the same or separate files.

### Directory Structure

- `machines/<hostname>/` - Per-machine configuration.nix and disko.nix
- `modules/system/` - NixOS feature modules (`nixosModules.*`)
- `modules/home/` - Home-manager feature modules (`homeModules.*`)
- `services/` - Custom Clan service modules (syncthing, tailscale)
- `sops/` - Age-encrypted secrets
- `vars/` - Clan vars (per-machine generated values like syncthing device IDs)
- `lib/` - Helper functions (e.g., mkClanSecretGenerators)

Files prefixed with `_` are excluded from auto-import (useful for WIP code).

### Adding New Features

1. Create module file in appropriate directory (`modules/system/` or `modules/home/`)
2. Use the flake-parts module pattern with `config.flake.<moduleClass>.<name>`
3. Import the feature in machine's `configuration.nix` via `modules.nixosModules.<name>` or `modules.homeModules.<name>`
4. For multi-context features, create aspects for each context

### Custom Options

Global options defined in `modules/system/options.nix`:
- `my.mainUser.name` - Primary user for the system
- `my.flakeHostname` - Hostname used for `nh os switch`

Package catalog in `modules/home/packages.nix` enables per-package toggles:
```nix
my.packages.firefox.enable = true;
```

### Clan Inventory

Machine deployment and service instances are configured in `flake.nix` under `flake.clan.inventory`. Services like syncthing and tailscale use Clan's role-based configuration with tags for grouping machines.

### Secrets Management

Uses both SOPS-nix and Clan's vars system:
- SOPS secrets in `sops/secrets/` (age-encrypted)
- Clan-generated vars in `vars/per-machine/` (e.g., syncthing certificates)
- Secret file mappings defined in `modules/system/secrets-sops.nix`

## Service Status

Target: Services exposed on clan network via dm-dns (e.g., `paperless.aon.clan`)

| Service | Module | abhaile | short | Status |
|---------|--------|---------|-------|--------|
| Syncthing | `services/syncthing` | sendonly | receiveonly | Partial - needs folder restructure |
| Paperless | `modules/system/paperless.nix` | client | host | Module exists, not deployed |
| Immich | - | client | host | Not started |
| BorgBackup | - | backup source | backup source | Not started |
| Caddy | `modules/system/caddy.nix` | - | reverse proxy | Basic setup, needs dm-dns |
| Tailscale | `services/tailscale` | peer | peer | Working |
| dm-dns | - | - | - | Not started |

**Machine roles:**
- `short`: Primary service host (Paperless, Immich, Syncthing receive). Test VM before VPS deployment.
- `abhaile`: Desktop client, Syncthing send-only for paperless/photos
- `eachtrach`: VPS, commented out until changes validated on short
- `nas-storage`: Future - BorgBackup primary store

## TODO

### Syncthing
- [ ] Restructure folders: `obsidian` (send/receive), `paperless` (send→receive), `photos` (send→receive)
- [ ] Update `flake.nix` inventory with new folder config

### Paperless (short)
- [ ] Import `paperless` module in `machines/short/configuration.nix`
- [ ] Configure Caddy reverse proxy route
- [ ] Setup dm-dns for `paperless.aon.clan`

### Immich (short)
- [ ] Create `modules/system/immich.nix`
- [ ] Configure Caddy reverse proxy route
- [ ] Setup dm-dns for `photos.aon.clan`

### BorgBackup
- [ ] Create borgbackup module or use clan's official module
- [ ] Configure short as backup source (syncthing/paperless/immich data)
- [ ] Daily cron job to NAS

### dm-dns
- [ ] Setup clan dm-dns service for LAN URLs
- [ ] Configure: `sync-<machine>.aon.clan`, `paperless.aon.clan`, `photos.aon.clan`, `borg.aon.clan`

### Infrastructure
- [ ] Validate changes on `short` VM
- [ ] Re-enable `eachtrach` in inventory after validation
- [ ] Acquire NAS/storage device
