# bbm on eachtrach

BBM — personal finance ledger. Go API + React SPA, tailnet-only, on the Hetzner VPS. App repo: `~/dev/bbm` (GitHub
`donskifarrell/bbm`). Deployed 2026-09-05.

## Shape

```
browser (tailnet) ──http──> caddy :80 on eachtrach
                              ├── /bbm.*  → reverse_proxy 127.0.0.1:8080   (ConnectRPC)
                              └── /*      → ${bbm-web} + try_files → /index.html (SPA)

bbm.service (user bbm) ── ConnectRPC API + in-process feed scheduler
                       └── /var/lib/bbm/{sqlite.db, data/}
```

- **One origin**: `http://eachtrach.tail8f3a60.ts.net`. The SPA is built with no `VITE_API_URL`, so it talks to whatever
  origin served it → no CORS in practice.
- **"Cron" is in-process.** `JOBS_MONITOR_INTERVAL` (5m) polls which feeds are due; each feed has its own
  `SYNC_INTERVAL` (default 6h, schema min 5m). One long-running unit, no systemd timer.
- Migrations embedded in the binary, applied at boot (`DB_AUTO_MIGRATE`, default true).

## Files

| Path                                               | What                                                  |
| -------------------------------------------------- | ----------------------------------------------------- |
| `modules/den/aspects/services/bbm.nix`             | flake input, user/group, unit, secrets, caddy vhost   |
| `modules/den/aspects/services/bbm-backup.nix`      | eachtrach snapshot + pull account; abhaile pull timer |
| `modules/den/aspects/services/caddy.nix`           | base caddy aspect (no vhosts of its own)              |
| `pkgs/by-name/bbm-deploy/package.nix`              | the deploy wrapper                                    |
| `~/dev/bbm/{flake.nix,nix/server.nix,nix/web.nix}` | the two package derivations                           |

## Deploying

```bash
bbm-deploy                 # commit locally in ~/dev/bbm first, then this. Builds on abhaile,
                           #   pushes the closure, deploy-rs magic rollback.
bbm-deploy --dry           # build + show what would change, don't switch
bbm-deploy --dirty         # deploy an uncommitted worktree (version string becomes -dirty)
bbm-deploy --src PATH      # a checkout somewhere else ($BBM_SRC also works)
bbm-deploy --pinned        # deploy the rev in flake.lock instead of a working copy
```

`bbm-deploy` overrides the `bbm` flake input per-invocation, so **flake.lock is not rewritten on every deploy**. That
means the lock can lag what is running — `--pinned` is what makes them agree; run `nix flake update bbm` when you want
the lock to record the deployed rev.

Frontend-only and backend-only changes rebuild only their own half (disjoint `lib.fileset` source sets in
`~/dev/bbm/flake.nix`).

## Secrets

`secrets/eachtrach.yaml`, key `bbm/`:

```yaml
bbm:
  gocardless_secret_id: ...
  gocardless_secret_key: ...
  jwt_secret_key: ... # openssl rand -hex 32; NOT the dev one from .env
  telegram_bot_token: ... # empty string = no bot, and that is a valid value
```

Assembled by `sops.templates."bbm.env"` into `/run/secrets/rendered/bbm.env` (owner bbm, 0400) and read by the app via
`ENV_FILE`. Deliberately **not** systemd `EnvironmentFile=`: that would put the values in the unit environment, visible
in `systemctl show` and `/proc/<pid>/environ`.

Non-secret config is plain `Environment=` in the unit — `systemctl cat bbm` shows all of it.

Adding/rotating: `sops secrets/eachtrach.yaml`, then `bbm-deploy`. No nix change.

## Access control

| Account      | Can                                                                                                    |
| ------------ | ------------------------------------------------------------------------------------------------------ |
| `bbm`        | own `/var/lib/bbm` (0750, umask 0027). Only account that writes.                                       |
| `bbm-backup` | primary group `bbm` → **read** only, by permission not policy. ssh key is `restrict` + forced command. |
| `caddy`      | world-readable store paths only. Never touches `/var/lib/bbm`.                                         |

The forced command (`bbm-backup-rsync-only`) accepts only `rsync --server --sender` under `/var/lib/bbm`. Verified
refusing: arbitrary commands, rsync push, reads outside the state dir. nixpkgs' rsync ships no `rrsync`, hence the
hand-written wrapper.

## Not publicly reachable

Enforced by the firewall, not by binding:

- `ts-input` (tailscale's own chain, runs first) accepts `tailscale0` + udp/41641.
- `nixos-fw` then accepts only tailscale0, lo, ESTABLISHED, tcp/22, udp/41641, icmp-echo → everything else hits
  `nixos-fw-log-refuse`. `allowedTCPPorts = [ 22 ]`.

**Testing this from abhaile is inconclusive** — abhaile selects eachtrach as its exit node, so
`curl http://91.99.168.74/` routes down the tunnel (`ip route get` shows `dev tailscale0 table 52`), arrives on
tailscale0 and is accepted. A real external check needs an off-tailnet vantage point.

Caddy binds 0.0.0.0 on purpose: binding the tailnet address would make caddy's startup depend on tailscaled, turning a
transient hiccup into a failed activation, for nothing the firewall does not already give.

## Backups

- **eachtrach** `bbm-snapshot.timer` 03:00 → `sqlite3 ".backup"` to `/var/lib/bbm/backup/sqlite.db`.
- **abhaile** `bbm-backup-pull.timer` 03:30 → rsync `/var/lib/bbm/` → `/var/lib/bbm-backup/daily.<date>/`, `--link-dest`
  against `latest`, 14 dailies kept, root:root 0700.

The live `sqlite.db`/`-wal`/`-shm` are **excluded**; only the `.backup` snapshot is kept. rsync-ing a live WAL database
gives a torn file that still looks valid — the worst way to discover a bad backup. `data/` is copied whole and is the
irreplaceable half: the ledger rebuilds from the raw feed pulls and uploads, not the other way round.

Restore: stop `bbm`, copy `daily.<date>/backup/sqlite.db` → `/var/lib/bbm/sqlite.db` (remove `-wal`/`-shm`), copy
`daily.<date>/data/` → `/var/lib/bbm/data/`, `chown -R bbm:bbm`, start `bbm`. Check a snapshot any time:
`sqlite3 <file> "pragma integrity_check;"`.

## Gotchas

- **`git+file:` not `path:` for the flake input.** `path:` copies the working directory verbatim — bbm's plaintext
  `.env`, `data/`, every `node_modules` — into the world-readable nix store. `git+file:` exports the git tree, honours
  `.gitignore`, deploys committed HEAD only.
- **The input is a local absolute path** (`/home/df/dev/bbm`), so this flake does not evaluate on a machine without it —
  `nix flake check`, `nix fmt` and `nixos-rebuild` all resolve every input and will fail there, not just for bbm.
  One-line switch to `git+ssh://git@github.com/donskifarrell/bbm`.
- **A relative path input cannot work**: nix resolves `path:../…` against the flake's _store_ copy → "access to absolute
  path '/nix/store/…' is forbidden in pure evaluation mode".
- **Stored files are 0750/0640, not 0700/0600** (changed in bbm 2026-09-05) so the backup account can read them. Files
  created before that change keep their old mode — this deploy needed a one-time `chmod -R g+rX /var/lib/bbm/data`.
- **rsync ownership**: the pull uses `-rlptD`, not `-a`/`--numeric-ids`. Carrying eachtrach's uid over landed the backup
  owned by unrelated local accounts on abhaile (`nm-iodine:nscd`), which could then read the ledger.
- **One Telegram token = one poller.** A second instance long-polling the same token gets
  `409 Conflict: terminated by other getUpdates request` and neither works reliably. The dev server in the `scoite-bbm`
  sandbox uses the token from `~/dev/bbm/.env` — the same one now in sops. Give production its own bot, or stop the dev
  poller.
- **GoCardless redirect is `http://`.** If GoCardless refuses a non-https redirect URI, flip `useTLS` in
  `services/bbm.nix` and add `services.web.caddy.tailscale-tls` to the host — that needs the tailnet admin console's DNS
  → HTTPS Certificates toggle ON first (it currently looks off: `CertDomains` is null).
- Plain HTTP means an insecure origin, so `navigator.locks` is unavailable; `api.ts` already falls back (token refresh
  goes cross-tab → per-tab single-flight). Nothing else in the app needs a secure context.
- `WEB_BASE_URL` is the single origin setting. The old `WEB_HOST`/`WEB_PORT`/`WEB_HTTP_PROTOCOL` triple still works but
  the two consumers used to disagree about its format — see bbm's 2026-09-05 changelog.
- Two bbm tests fail on `main` for reasons that predate this work and are unrelated to deployment: `internal/db`
  `TestMigrationsDownWithLinkedFeedAndConsent` (migration 22 drops a view that 19's down step expects; rollback path
  only) and `internal/telegram` `TestUnlinkedChatIsNotAnswered` (flaky, fails 3/3 in a package run, passes with `-run`).
  `internal/gocardless` also times out locally.
