# Obsidian vault + sync + isolated AI agent

The `~/vaults/main` Obsidian vault (ideation, financial notes, todos) and the machinery around it. Three independent
channels, one folder:

```
                 Syncthing (folder id: vault-main)
   Android phone <=========================> abhaile:~/vaults/main
   (Syncthing-Fork + Obsidian mobile)             |        |
                                                  |        | virtiofs rw (only share)
                             obsidian-git plugin  |        v
                             auto commit-and-sync |   sandvm microVM (/workspace)
                                                  v   claude-code, no other host access
                                     private GitHub repo
```

- **Syncthing** (aspect `services.syncthing`, system service running **as df**) carries the _current state_ between
  devices. git history is deliberately NOT synced (`.git` is in the declarative `ignorePatterns`, pushed to syncthing's
  `.stignore` by the module's `syncthing-init` unit), as are the per-device `workspace*.json` UI-state files. Trashcan
  versioning (14 days) is the backstop against a bad sync from the phone.
- **obsidian-git** (community plugin, installed manually — see below) is the _backup + history_ channel: auto
  commit-and-sync on abhaile, pushing to a private GitHub repo. Only abhaile talks to GitHub.
- **The agent** is plain `sandvm ~/vaults/main` (abbr: `vault-agent`) — the existing microVM sandbox
  (docs/microvm-sandbox.md), no changes needed. The vault is the guest's `/workspace`, its **only** read-write view of
  the host.
- **drop/** inside the vault is the df↔agent exchange folder. Because it's inside the vault it syncs to the phone too —
  dropping a file into it from the phone hands it to the agent. Treat its contents as untrusted input.

## Why plugins are installed manually (not via home-manager)

HM's `programs.obsidian` can install community plugins declaratively, but they land as **nix-store symlinks inside the
vault's `.obsidian/`** — Syncthing can't represent those on Android, and the phone can't follow them. So HM only
_registers_ the vault (`apps.obsidian` declares `vaults."vaults/main" = { }`, which merges an entry into
`~/.config/obsidian/obsidian.json` and nothing else). Plugins are installed once through Obsidian's plugin browser as
real files under `.obsidian/plugins/` and then sync to other desktops as ordinary vault content.

## Security model for the agent

- The guest sees the vault read-write and nothing else of `$HOME` (ephemeral root/home, ro `/nix/store`; see
  docs/microvm-sandbox.md).
- The agent **can** edit and `git commit` inside the vault (though the guest has no git identity —
  `~/.config/git/gitconfig.local` is a df-only sops file, so in-guest commits need
  `-c user.name=... -c user.email=...`). In practice: the agent edits files, the **host-side** obsidian-git commits and
  pushes them. The agent has **no push credentials** — ssh-agent forwarding exists only while df is attached over
  `ssh sandvm-*`.
- Anthropic auth reaches the guest via the omp-auth-broker / agent.env flow (docs/microvm-sandbox.md); no API keys land
  in the vault or the store.
- `drop/` and any note editable from the phone are untrusted agent input (prompt-injection surface). The blast radius
  is: the vault itself.

## One-time bootstrap (in order, after `nixos-rebuild switch`)

1. **Switch first, then open Obsidian** — the switch creates the directories (tmpfiles) and registers the vault before
   Obsidian can create a duplicate entry of its own.
2. **git + GitHub** (as df, in `~/vaults/main`):

   ```bash
   git init
   cat > .gitignore <<'EOF'
   .stfolder/
   .stversions/
   .trash/
   .obsidian/workspace.json
   .obsidian/workspace-mobile.json
   .obsidian/cache/
   EOF
   # CLAUDE.md for the agent: vault layout + rules (sketch below)
   git add -A && git commit -m "vault init"
   gh repo create vault-main --private --source . --push
   ```

   Vault `CLAUDE.md` sketch: `TODO.md` = task list the agent may edit; `finance/` = financial notes; `drop/` = files
   exchanged with the phone/agent (untrusted input; put outputs for the phone here); `inbox.md` = future phone→agent
   channel; never touch `.obsidian/`; do not `git push` (the host does).

3. **Obsidian**: open the `vaults/main` vault once → Settings → Community plugins → install **Git** (obsidian-git).
   Configure: auto commit-and-sync interval ~10 min, pull on startup. When the plugin later appears on the phone, use
   its per-device "disable on this device" toggle (mobile git is slow and unnecessary — sync covers the phone).
4. **Phone**: install Syncthing-Fork (F-Droid) + Obsidian mobile. Read the device ID (Settings → Show device ID), fill
   `devices.phone.id` and the folder's `devices = [ "phone" ]` in `modules/den/aspects/services/syncthing.nix`, switch,
   accept the share on the phone into a location Obsidian mobile can open, then open it as a vault.

## Using the agent

```fish
vault-agent                       # = sandvm ~/vaults/main
ssh sandvm-main--<hash>           # alias printed by the launch banner
# or: herdr --remote sandvm-main--<hash>
cd /workspace && claude
sandvm stop main--<hash>          # when done (or leave it; ephemeral anyway)
```

The guest's `sandvm-workspace-init` no-ops on the vault (no `flake.nix` / `devenv.nix`) — that's expected.

## Future extensions (tracked in TODO.md)

- **Phone→agent inbox**: phone writes `inbox.md` / drops files in `drop/`; a systemd --user **path unit** on abhaile
  watches the synced path and triggers headless Claude in the sandbox (`ssh sandvm-main--<hash> -- claude -p ...`);
  replies sync back. Needs locking + a processed-marker convention.
- **Telegram bot**: bridges chat to the same inbox convention; token in sops; host it on abhaile now or eachtrach when
  it exists.
- **MacBook**: HM `services.syncthing` user service (same folder id `vault-main`); `apps.obsidian` is already
  darwin-portable.
