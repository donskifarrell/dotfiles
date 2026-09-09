# bbm on eachtrach

BBM — personal finance ledger. Go API + React SPA, tailnet-only, on the Hetzner VPS. App repo: `~/dev/bbm` (GitHub
`donskifarrell/bbm`). Deployed 2026-09-05.

## Shape

```
browser (tailnet) ──http──> caddy :80 on eachtrach
                              ├── /bbm.*  → reverse_proxy 127.0.0.1:8080   (ConnectRPC)
                              └── /*      → ${bbm-web} + try_files → /index.html (SPA)

bbm.service (user bbm) ── ConnectRPC API + in-process feed scheduler
                       ├── /var/lib/bbm/{sqlite.db, data/}
                       └──http──> 127.0.0.1:8091  bbm-charts.service (DynamicUser)
                                                   POST /weekly {points} -> PNG
```

- **One origin**: `http://eachtrach.tail8f3a60.ts.net`. The SPA is built with no `VITE_API_URL`, so it talks to whatever
  origin served it → no CORS in practice.
- **"Cron" is in-process.** `JOBS_MONITOR_INTERVAL` (5m) polls which feeds are due; each feed has its own
  `SYNC_INTERVAL` (default 6h, schema min 5m). One long-running unit, no systemd timer.
- Migrations embedded in the binary, applied at boot (`DB_AUTO_MIGRATE`, default true).

## Files

| Path                                            | What                                                  |
| ----------------------------------------------- | ----------------------------------------------------- |
| `modules/den/aspects/services/bbm.nix`          | flake input, user/group, unit, secrets, caddy vhost   |
| `modules/den/aspects/services/bbm-backup.nix`   | eachtrach snapshot + pull account; abhaile pull timer |
| `modules/den/aspects/services/caddy.nix`        | base caddy aspect (no vhosts of its own)              |
| `pkgs/by-name/bbm-deploy/package.nix`           | the deploy wrapper                                    |
| `~/dev/bbm/nix/{server.nix,web.nix,charts.nix}` | the three package derivations                         |
| `~/dev/bbm/web/packages/charts/`                | the sidecar's source (`@bbm/charts`)                  |

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
`~/dev/bbm/flake.nix`). `bbm-charts` shares the SPA's source set, so a website commit rebuilds it too — the lockfile has
an importer entry for `apps/website`, and a `--frozen-lockfile` install of a tree missing that directory fails.

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

Adding/rotating: `sops secrets/eachtrach.yaml`, then `bbm-deploy`. No nix change. Both templates carry
`restartUnits = [ "bbm.service" ]`, so a changed value restarts the app instead of leaving the old one resident.

## Environment layering

bbm's `internal/config` reads three layers, later winning: the base `.env`, then the overlay `.env.$ENV`, then exported
variables. `ENV_FILE` names the base, and **its directory is the root the overlay is looked up in** — which is the whole
reason both files are rendered into `/run/secrets/rendered`.

| Layer                             | Where on eachtrach                        | Holds                                                                      |
| --------------------------------- | ----------------------------------------- | -------------------------------------------------------------------------- |
| base (`ENV_FILE`)                 | `/run/secrets/rendered/bbm.env`, 0400 bbm | secrets only                                                               |
| overlay (`.env.$ENV`, `ENV=prod`) | `/run/secrets/rendered/.env.prod`, 0444   | prod-only **app** config. No secrets, hence world-readable and inspectable |
| exported                          | `Environment=` in the unit                | what this NixOS host derives: ports, state paths, `WEB_BASE_URL`, `ENV`    |

The overlay is the counterpart of `~/dev/bbm/.env.prod`, **rendered rather than copied**. That file is `.gitignore`'d,
so the `git+file:` export the host builds from cannot see it, and copying it out of band would put a deploy's config
outside the closure (a from-scratch provision or a rollback would not carry it) and its bot token outside sops.

The cost is drift, so `bbm-deploy` warns when `$src/.env.prod` sets a key that `services/bbm.nix` never mentions. It is
a warning, not an error: a key can be local-only on purpose.

Currently the overlay holds `APP_LOG_LEVEL=debug` and `CHART_RENDER_URL=http://127.0.0.1:8091`.

## Chart sidecar (`bbm-charts.service`)

The Telegram weekly report's 52-week chart. `bbm` POSTs `{points, currency}` to `127.0.0.1:8091/weekly` and gets a PNG
back. It exists so there is **one** chart implementation — the SPA's own Recharts component, rendered in jsdom and
rasterised by resvg — instead of a second Go charting library that would drift from what the web app shows. No browser
and no headless Chrome.

**It is optional by design.** `internal/telegram/reports.go` calls the chart "a bonus": a renderer that is down or slow
is logged and the report goes out as text. This unit can never fail a deploy or cost you a report.

`node src/server.ts` runs the TypeScript directly — Node 24 strips the types — so a stack trace names a line you can
read. `pnpm deploy` prunes the 449M workspace to a 78M self-contained tree; the closure is ~310 MiB, mostly nodejs.

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

- **`ENV` must be exactly `prod`, not `production`.** The overlay filename is built from it (`.env.$ENV`), so the
  original `ENV = "production"` looked for a `.env.production` that has never existed and applied no overlay at all —
  silently, because a missing overlay is legal (`readEnv` returns an empty map for a file that is not there).
- **`APP_LOG_LEVEL` is read by nothing.** `.env.example` documents `debug | info | warn | error`, but no Go code reads
  the key — the app logs with plain `log.Printf` and has no level machinery at all. It is set to `debug` in the overlay
  because that is the intent; it will do nothing until the app grows a logger.
- **The sidecar must NOT get `MemoryDenyWriteExecute`.** `bbm.service` sets it; copying that line to `bbm-charts` kills
  node at startup, because V8's JIT maps pages writable and then executable. `bbm-charts` gets `IPAddressDeny=any`
  instead, which `bbm` cannot have (it calls GoCardless and Telegram).
- **`jsdom` is a runtime dependency of `@bbm/charts`, not a dev one.** `src/render.ts` imports it. It was in
  `devDependencies`, which made `pnpm deploy --prod` produce a tree that could not start — fixed 2026-09-09 by moving
  it, which also touched `pnpm-lock.yaml` and both pnpm deps hashes.
- **`pnpm deploy` in a sandbox needs `--config.inject-workspace-packages=true`.** The two implementations fail in
  opposite ways: `--legacy` re-resolves from the registry (`ERR_PNPM_NO_OFFLINE_META` under `--offline`), and without
  the flag pnpm >=10 refuses outright (`ERR_PNPM_DEPLOY_NONINJECTED_WORKSPACE`). The modern path builds from the shared
  lockfile and the local store, which is what works offline. `npm_config_inject_workspace_packages` in `env` does
  **not** work — pnpm 11 ignores it for this setting; it has to be the `--config.` CLI form.
- **An exported variable beats both env files.** A key set in the unit's `Environment=` _and_ in the rendered
  `.env.prod` is a dead line in the overlay. Put host-derived values in the unit, app config in the overlay, never both.
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
