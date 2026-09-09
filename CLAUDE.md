# CLAUDE.md

Guidance for Claude Code working in this repo.

## Rules:

1. Update CLAUDE.md file as you learn more about the system and architecture. Pay attention to easily forgot details for
   example, how to add or edit secrets.
2. Branch off to a separate document file in docs/ if information is niche or too verbose.
3. Maintain a file that tracks TODOs. Each TODO should contain enough detail (or link somewhere with more detail) on
   exactly what needs to be done. It should be good enough to hand off to another model to execute. The TODO file should
   contain a table with a prioritised list of items to action, along with their status. Many models/humans may interact
   with this file.
4. Start in PLAN mode and only write once ready.
5. Do NOT ask for permissions to read any file and run any script/program that will read files too. You are allowed. You
   can write to any .md file as needed. Only ask for permission to execute Write commands outside the repo.
6. Do NOT stage or commit files in git unless I give permission
7. Comments should be concise with detailed packed. Sacrifice grammer for conciseness.

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
                          `nix run .#write-flake` regenerates flake.nix; also imports Den's dendritic
                          flakeModule), devshell.nix, treefmt.nix, pre-commit.nix, deploy.nix
                          (deploy-rs nodes from every real host), pkgs.nix (auto-wires pkgs/by-name),
                          den-tree.nix
  den/                  the whole NixOS/HM config Den builds:
    den.nix              global Den defaults (batteries, HM user class)
    hosts/<host>.nix     emits nixosConfigurations.<host> (composes aspects + machine data)
    aspects/             feature modules by category: core, hardware, shell, dev,
                         services, secrets, apps, gaming, virtualisation
    roles/               aspect bundles: default, workstation, dev, desktop,
                         server (headless/BIOS — eachtrach),
                         sandbox.{minimal,dev} (the two scoite guest tiers)
    users/df.nix         the df user aspect (home-manager)
    users/iosta.nix      the scoite-guest-only user: uid pinned 1000 (virtiofs); its tier
                         is chosen per guest host, not here
hosts/<host>/          machine data imported by that host: disko.nix + facter.json
secrets/*.yaml         sops-nix encrypted secrets (shared.yaml = multi-host, <host>.yaml = per-host)
.sops.yaml             sops recipients + creation rules
.mcp.json              Claude Code MCP servers for this repo (nixos = mcp-nixos via `nix run`)
```

An aspect is `den.aspects.<path>.{nixos|homeManager|darwin} = <module>`; reference it in an `includes` list as `<path>`
(e.g. `core.network.openssh`). Files/dirs prefixed `_` are excluded from auto-import.

**Host includes only apply an aspect's `nixos` side; user includes only its `homeManager` side** — the host->user
projection (`den.batteries.host-aspects`) is deliberately off in `users/df.nix`. So an aspect with both sides (e.g.
`services.tailscale`: daemon + `tailscale systray` user unit) must be listed in **both** `hosts/<host>.nix` and
`users/df.nix`; the halves are still defined once, in the aspect.

## Machines

| Host      | System         | Role                                                                                                                                                                                                                                                                                                                           |
| --------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| abhaile   | x86_64-linux   | df's AMD desktop workstation (LUKS root, systemd-boot)                                                                                                                                                                                                                                                                         |
| eachtrach | x86_64-linux   | Hetzner x86 VPS (2 vCPU/4 GB/40 GB) — tailscale **exit node**, headless, no users. Adopted in place from its clan bootstrap 2026-09-04 (not reprovisioned). BIOS boot → `roles.server` (grub, not systemd-boot). Tailscale SSH off, so `ssh eachtrach` / `deploy .#eachtrach` reach the real sshd as **root** over the tailnet |
| (macbook) | aarch64-darwin | (planned) df's MacBook Pro on nix-darwin + homebrew — inputs already kept for it                                                                                                                                                                                                                                               |

## Common commands

```bash
nixos-rebuild switch --flake .#abhaile      # build + activate locally (nh also configured)
nix flake check                              # treefmt + flake-file + deploy-rs deployChecks (the
                                             #   latter re-evaluates every deploy node's toplevel);
                                             #   to fully verify a host, build its toplevel:
nix build .#nixosConfigurations.abhaile.config.system.build.toplevel
nix fmt                                       # nixfmt + nixf-diagnose (+ shellcheck/prettier/…, treefmt)
nix flake update                              # update inputs (commit flake.lock on its own)
deploy .#<host>                               # deploy-rs remote day-2 (nodes auto-generated per host
                                              #   in modules/flake-parts/deploy.nix; magic rollback)
nixos-anywhere --flake .#<host> root@<ip>     # provision a new host (kexec's Ubuntu images into NixOS)
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
- **eachtrach is deliberately NOT a recipient of `shared.yaml`** — it is internet-facing, and a recipient there can
  decrypt df's GitHub ssh private keys. Its one secret lives in `secrets/eachtrach.yaml`. Keep it that way; if it ever
  needs something from shared.yaml, move that value to its own file rather than adding the recipient.

## eachtrach — Hetzner VPS / tailscale exit node

Headless x86 VPS, **adopted in place** on 2026-09-04 from its 2025-10-26 clan.lol bootstrap — it was never
reprovisioned, so `hosts/eachtrach/{disko.nix,facter.json}` describe a disk that already exists (both recovered verbatim
from `git show 220c93e^:machines/eachtrach/…`; the derived partlabels were checked against the live
`/dev/disk/by-partlabel` before deploying). Composed from `roles.server` + `services.tailscale{,.exit-node}` +
`secrets.{sops,eachtrach}`. Deploy with `deploy .#eachtrach`.

Gotchas (easy to forget):

- **Tailscale SSH is OFF here** (`services.tailscale.no-ssh`), and that is load-bearing. While it was on, tailscaled
  intercepted port 22 on the tailnet ip before sshd saw it and applied the tailnet ACL: `ssh eachtrach` tried user `df`
  and was denied outright, root was gated behind an interactive "visit this URL" browser check, and that same check hung
  non-interactive `deploy` (which is why deploys briefly used the public ip instead). With it off, port 22 on the
  tailnet is the real sshd — plain key auth over WireGuard — so both `ssh eachtrach` and `deploy .#eachtrach` use the
  bare name. Cost: no browser-auth fallback; recovery is the ssh key or Hetzner's web console.
- **Turning a tailscale pref off needs `--flag=false`, not the absence of a flag** — prefs persist in
  `/var/lib/tailscale`. And `tailscale set --ssh=false` **exits 1** without `--accept-risk=lose-ssh` ("you are connected
  using Tailscale SSH…"), which it raises even when the caller is not on a Tailscale SSH session. A non-zero exit from
  `tailscaled-set.service` fails activation, so omitting it makes every deploy of this host roll back.
- **`ssh eachtrach` needs `User root`** — the host declares no users. That block lives in `core.network.ssh`
  (`settings."eachtrach".User = "root"`), so it reaches `~/.ssh/config` only after a `nixos-rebuild switch` on abhaile.
- Creating `/etc/ssh/ssh_host_ed25519_key` during the adoption also made **Tailscale SSH switch from its own
  self-generated host key to the machine's real one**, so a stale `known_hosts` line for the raw tailnet ip
  (`100.82.196.62`) caused a REMOTE HOST IDENTIFICATION HAS CHANGED warning. Cleared 2026-09-05 with `ssh-keygen -R`.
- **Exit-node advertisement is `extraSetFlags`, never `extraUpFlags`.** `tailscaled-autoconnect` returns the moment the
  backend state is `Running`, so on an already-joined node an `extraUpFlags` entry is never applied. `extraSetFlags`
  becomes `tailscaled-set.service` — a `tailscale set …` that runs every activation and is idempotent.
- **No `networking.nat`.** tailscaled does its own exit-node SNAT (`ts-postrouting` … `-j MASQUERADE`, NetfilterMode=2);
  `useRoutingFeatures = "both"` supplies the forwarding sysctls. Adding networking.nat would be a second, conflicting
  NAT — and the uplink is `enp1s0`, not the `eth0` the old dead code guessed.
- **`facter.detected.dhcp.enable` must be forced back on** (`hosts/eachtrach.nix`). The shared `hardware.facter` aspect
  turns it off for abhaile's sake (NetworkManager drives that host); eachtrach gets its address from exactly that
  module, so without the `mkForce` the box comes up with **no default route**. Hetzner hands out a /32 whose gateway is
  off-prefix, so keep `networking.useNetworkd = true` too — that is what the box already ran.
- **`system.stateVersion` needs `lib.mkForce "25.11"`** — `core.stateVersion` sets 26.11 as a plain definition.
- `roles.server` excludes `core.home-manager` as well as `core.systemd.boot`: with no users declared, Den's home-manager
  battery never imports the HM NixOS module, and `core.home-manager`'s settings then fail to evaluate.
- `core.boot.grub` pins `boot.initrd.systemd.enable = false`. This nixpkgs defaults it to **true**, and eachtrach was
  adopted on a scripted initrd — flip it as its own reboot-verified step, not folded into another change.
- **First switch off a 25.11 clan system fails once**, on `Failed to reload user unit dbus-broker.service` → "user
  activation for root failed" → deploy-rs rolls back. 25.11→26.11 swaps dbus-daemon for dbus-broker, and activation
  tries to _reload_ root's user dbus-broker before it is running. **Just run `deploy` again** — it succeeds. Watch out
  for the in-between state: the rollback leaves the new system running with the profile pointed at the old generation.
- The machine's ssh host key predates the adoption. It lived only on a clan tmpfs (`/run/secrets/vars/openssh/…`), and
  was copied to `/etc/ssh/ssh_host_ed25519_key` so sops-nix could use it — so the **fingerprint never changed**, and
  `age16fyjpn3uu2qyp824tnn5aw0hg9d642qe8llj9xl3lpcfc77ysczqxghhgw` in `.sops.yaml` is derived from it.
- Adoption dropped the clan-era caddy site, the `gh_deployer` SFTP user and the `mise` account. Declaring no users
  removes users NixOS used to manage — `mutableUsers = true` protects _unmanaged_ accounts and passwords (root's
  password, the only way into Hetzner's web console, survives), not ones this config stopped declaring. Home directories
  are never deleted by user removal; `/srv/www` is still on disk, unserved.

## Obsidian vault + sync + vault agent (abhaile)

**Full reference: [docs/obsidian.md](docs/obsidian.md)** — vault `~/vaults/main` (registered by `apps.obsidian`; `drop/`
= phone/agent exchange folder), Syncthing to the Android phone (`services.syncthing`, runs as df, declarative
`.stignore` excludes `.git`), obsidian-git plugin (installed manually — HM plugin installs are store symlinks that break
sync to Android) pushes to a private GitHub repo, and the isolated agent = `scoite ~/vaults/main` (abbr `vault-agent`;
the vault is the guest's only writable host view). Follow-ups + phone→agent/Telegram sketches: TODO.md item 17.

## Sandboxed microVMs for agents — `scoite` (abhaile)

**Full reference: [docs/microvm-sandbox.md](docs/microvm-sandbox.md)** — `scoite` (alias `sc`)
`new|start|stop|rm|rename|ssh|creds|list|resize|expose|unexpose`, **two** guest types (`minimal` / `dev`, one Den host
each in `hosts/scoite.nix`, tiers in `roles/sandbox.nix`), guest user `iosta`, `/workspace` the only writable host
channel. An instance is `scoite-<name>` everywhere: state dir, ssh alias, systemd unit, guest hostname, mDNS name.
Per-instance state lives in `~/.local/state/scoite/<name>/` (a `config` file plus two sparse volumes: the nix store
overlay and a persistent `/home/iosta`).

The 2026-08-24/25 rework (rename from `sandvm`, two types, bridge networking + `.local` names, LAN exposure, live config
propagation) is tracked step by step with its verifications in [TASKS.md](TASKS.md); goals in [GOAL.md](GOAL.md). Parts
of both files describe omp and paseo, which were dropped on 2026-09-08 — read them as history.

Gotchas (easy to forget):

- **Nothing per-instance may enter the guest's `system.build.toplevel`** — that invariant is what lets every sandbox of
  a type share one built closure. Per-launch values (workdir, ports, cpu/mem, disk sizes, MAC, credential paths) may
  only touch `microvm.*` options that end on qemu's command line. The guest hostname is the static string `sandbox` for
  exactly this reason; the real name arrives as a boot credential.
- `scoite` is home-manager-installed: edits to `pkgs/by-name/scoite/package.nix` need a `nixos-rebuild switch` before
  they reach `$PATH`.
- **Two NICs.** `eth0` is SLIRP and keeps the default route: guests reach abhaile at `10.0.2.2` (llama-server :8080,
  harmonia :5000 — unsigned by design). `eth1` is a tap on the host bridge `scoitebr0` (10.77.0.0/24, DHCP + `ip rule`
  beating tailscale's table 52) and exists so a guest has an inbound address and an mDNS name. Restarting
  `scoite-bridge.service` must never delete the bridge — that detaches every running guest's tap.
- **`scoite-<name>.local` resolves from abhaile** (guest `systemd-resolved` publishes, host avahi + `nssmdns4` resolve).
  Nothing is reachable from the LAN unless you say so: `scoite expose --lan <port>` installs an iptables DNAT via the
  root helper `scoite-lan`, recorded per instance and re-applied on start. With a tailscale exit node selected, LAN
  reachability also needs `--exit-node-allow-lan-access` (now set in `services/tailscale.nix`).
- Credentials reach the guest as qemu `fw_cfg` systemd credentials, never through `/nix/store`: pass **string** paths,
  never Nix path literals, or the file gets copied into the world-readable store at eval time.
- Git auth in a guest = **forwarded ssh-agent + `~/.ssh/sshconfig.local`**. The alias config and the _public_ halves of
  the keys it names ride in as the `SSH_CONF` credential; private keys never do. A remote using a bare `github.com` URL
  works either way — one using `<acct>.github.com` needs that config. GitHub only accepts the user `git`: every alias
  block carries `User git` (added 2026-08-28) so the bare `ssh -T <alias>` forms work, not just `git@<alias>` remotes.
- **`nix`/`devenv` fetches use libgit2, which reads only `~/.ssh/known_hosts`** — not `/etc/ssh/ssh_known_hosts`, where
  `programs.ssh.knownHosts` puts the guest's pinned github key. Combined with df's
  `url."git@github.com:".insteadOf = "https://github.com/"`, every `github:` flake input goes out over ssh, so a guest
  with no `~/.ssh/known_hosts` fails to lock a single input with the misleading
  `connecting to remote 'https://…': invalid or unknown remote ssh hostkey` (libgit2's `GIT_ECERTIFICATE` text — it is
  not a CA/TLS problem, and `SSL_CERT_FILE` does nothing). A tmpfiles `C` rule now seeds that file; see
  docs/microvm-sandbox.md.
- Running sandboxes don't pick up _system_ config changes — stop and start them. **Host identity is the exception**:
  `scoite creds [<name>|--all]` re-pushes agent.env, ssh config and gitconfig into a _running_ guest, and runs on every
  `scoite ssh` plus a 10-min host timer. New guest shells only.
- **A guest must never be interrupted while Nix substitutes into its store overlay.** Nix deletes a path before
  re-extracting it, and through an overlay that leaves an opaque upper directory hiding the host's intact copy — so a
  half-finished substitution replaces working binaries with truncated ones (no coreutils, `ETXTBSY` on exec, a
  `nix-store` that SIGBUSes on its own libraries). Recovery is discarding `nix-store-overlay.img`, not repair from
  inside. Two guards, both required, both in `microvm-guest.nix`: `register-nix-paths` seeds the guest Nix db from the
  cmdline `regInfo=` at boot so activation has nothing to substitute (nixpkgs ships this only in `qemu-vm.nix`, which
  microvm.nix does not import), and `TimeoutStartSec` is forced to `infinity` on `home-manager-iosta` because
  home-manager hardcodes 5m and its SIGTERM is what triggered this on 2026-09-08. Details: docs/microvm-sandbox.md.
- Guest-side installers called from systemd units need **absolute store paths** — a unit's PATH has no
  `/run/current-system/sw/bin`, and the failure is a swallowed "command not found" at boot while the push path works.
- **omp and paseo were dropped on 2026-09-08** (df moved to `pi` + `herdr`). Gone with them: the
  `dev.tools.omp-auth-broker` aspect and its shared-Anthropic-credential broker on `:8765`, `dev.tools.paseo` and its
  `:6767` daemon in every `dev` guest, the sandbox `omp` wrapper, the host→guest omp-config 9p share, and the generated
  guest `models.yml`. A guest agent's own credentials now come from `~/.config/scoite/agent.env` (cloud keys), the
  CLAUDE_CREDS credential (claude-code), or a `scoite bind ~/.pi` for pi's config — nothing brokers them any more.
- Model ids/context sizes for llama-server are generated from `modules/den/aspects/services/_llm-models.nix` — edit
  that, not `services/llm.nix`. `guestBaseUrl` there (`http://10.0.2.2:8080/v1`) is what to point a guest-side agent at
  by hand; nothing generates guest agent config from it any more.
- `llmfit` (model-vs-hardware sizing TUI) is installed by the same aspect and **pinned ahead of nixpkgs** by the overlay
  in `services/_llmfit.nix` (nixpkgs lags). Bumping it means version + src hash + `cargoDeps` hash — NOT `cargoHash`,
  which `buildRustPackage` reads off `args` so `overrideAttrs` can't reach it. Recipe: docs/llm.md.
- **systemd caps an fw_cfg credential at 1 MiB and drops a larger one silently** — the reason the (now removed) omp
  config travelled on a 9p share instead. Any future host→guest config tree bigger than a few hundred KB needs the same
  treatment; `scoite bind` is the ready-made answer.
- A guest login **waits** for `scoite-workspace-init` (the boot-time devenv/flake pre-build) instead of racing it — two
  concurrent devenv evaluations of the same `/workspace` fail. Also: `setcap` on a workspace file cannot work
  (unprivileged virtiofsd, no `security.capability` xattr).
- `scoite bind <host-dir> [<guest-dir>]` shares an extra host folder into a guest, live both ways (virtiofs, uid
  passthrough) — e.g. `~/.pi` <-> `/home/iosta/.pi`. **Four fixed slots**, applied at boot (bind/unbind needs a
  stop/start), `--ro` enforced host-side by virtiofsd. The slots exist to keep the single-closure invariant: a share's
  `mountPoint` is in the toplevel but its `source` is not, so the host paths stay on qemu's command line and the guest
  destinations arrive as the `BINDS` credential. Unused slots still get a virtiofsd (qemu will not start without the
  socket) pointed at an empty read-only placeholder. Slot count lives in **two** places that must agree: `bindSlots`
  (microvm-guest.nix) and `BIND_SLOTS` (pkgs/by-name/scoite/package.nix). It is the one deliberate hole in "workspace is
  the only writable host channel" — credential paths are refused without `--force`.
- herdr is back in both `roles.dev` (abhaile) and the `dev` sandbox tier, with `dev.tools.herdr.autostart`: an
  interactive `ssh scoite-<name>` `exec`s straight into herdr, so detaching ends the ssh session. A non-herdr shell (the
  serial console, a VS Code terminal) still lands in a plain fish in `/workspace`.

## bbm — personal finance app on eachtrach

**Full reference: [docs/bbm.md](docs/bbm.md)** — BBM (Go API + React SPA) from `~/dev/bbm`, tailnet-only at
`http://eachtrach.tail8f3a60.ts.net`, behind caddy (`/bbm.*` → the API, everything else the SPA). Deploy with
`bbm-deploy` (wraps deploy-rs; overrides the `bbm` flake input from a local checkout, so flake.lock is not rewritten per
deploy). Own user/group `bbm`; a separate read-only `bbm-backup` account exists purely for abhaile's nightly pull into
`/var/lib/bbm-backup`.

Gotchas (easy to forget):

- The `bbm` flake input is **`git+file:///home/df/dev/bbm`** — an absolute local path, by choice (deploy local commits,
  no push). So this flake does not evaluate on a machine without that path: `nix flake check`, `nix fmt` and
  `nixos-rebuild` all fail there, not just bbm. One-line switch to the GitHub URL.
- **Never change that input to `path:`** — `path:` copies the worktree verbatim, which would put bbm's plaintext `.env`,
  its `data/` bank files and every `node_modules` into the world-readable nix store. `git+file:` exports the git tree
  (honours .gitignore, committed HEAD only).
- A **relative** path input is impossible: nix resolves `path:../…` against the flake's _store_ copy.
- `bbm-deploy` deploys **committed HEAD**, not your worktree (`--dirty` overrides). flake.lock can therefore lag what is
  running; `nix flake update bbm` makes them agree.
- Secrets are one sops **template** (`/run/secrets/rendered/bbm.env`, read via `ENV_FILE`), not `EnvironmentFile=` —
  values stay out of `systemctl show` and `/proc/<pid>/environ`. Add/rotate with `sops secrets/eachtrach.yaml` +
  `bbm-deploy`; no nix change.
- **Env layering: base (`ENV_FILE`) → `.env.$ENV` overlay → exported vars, later wins.** The overlay is looked up in
  `dirname(ENV_FILE)`, so `.env.prod` is a _second_ sops template rendered beside `bbm.env` (0444, no secrets) — it is
  rendered, not copied, because `~/dev/bbm/.env.prod` is gitignored and holds a bot token. `ENV` must be exactly `prod`;
  `production` finds no overlay and says nothing. Never set a key in both the unit's `Environment=` and the overlay —
  exported wins, so the overlay line is dead. `bbm-deploy` warns on keys in `~/dev/bbm/.env.prod` that
  `services/bbm.nix` never mentions.
- Stored statement files are **0750/0640** so `bbm-backup` can read them; the backup pull uses `-rlptD` (not `-a`) so
  the copy lands root-owned on abhaile.
- **Chart sidecar** `bbm-charts.service` (loopback `:8091`, DynamicUser) renders the Telegram weekly chart from the
  SPA's own Recharts component via jsdom + resvg. Built by `~/dev/bbm/nix/charts.nix` (`pnpm deploy` needs
  `--config.inject-workspace-packages=true` to work offline). Optional by design — down means text-only reports, never a
  failed deploy. Never give it `MemoryDenyWriteExecute`: V8's JIT needs W then X.
- **`APP_LOG_LEVEL` is inert** — documented in `.env.example`, read by no Go code. The app has no log levels.
- **One Telegram token = one poller.** The `scoite-bbm` sandbox runs a dev server on the same token from
  `~/dev/bbm/.env` → `409 Conflict` on both. Give production its own bot.
- Runs on plain **HTTP** over the tailnet (firewall, not binding, is the enforcement — `allowedTCPPorts = [ 22 ]` plus
  tailscale's trusted interface). Moving to a real ts.net cert = `useTLS` in `services/bbm.nix` +
  `services.web.caddy.tailscale-tls`, and the tailnet HTTPS toggle must be on.
- Testing public reachability **from abhaile is inconclusive** — abhaile uses eachtrach as its exit node, so a curl to
  its public IP goes down the tunnel and is accepted.

## Local LLM inference (abhaile)

**Full reference: [docs/llm.md](docs/llm.md)** — benchmark numbers + what they mean per use case, llama-server parameter
research, model recommendations, re-bench protocol. Config: `services.llm` aspect (+ `hardware.gpu.rocm` diagnostics).
Summary: llama-server + **Vulkan** backend (won on-box benches; ROCm kept installed — wins MoE prompt processing),
router mode serving multiple models on `127.0.0.1:8080` (OpenAI-compatible), models in `/var/lib/llm/models`. Ollama
dropped (slower, measured); vLLM skipped (RDNA4 kernel gap, vllm-project/vllm#28649).

Gotchas (easy to forget):

- Models must NOT live in `$HOME` — the service is DynamicUser + `ProtectHome=true`.
- Device 0 = RX 9070, device 1 = Raphael iGPU in both stacks — always pin (`--device Vulkan0` / `-dev ROCm0`).
- `/dev/kfd` + `/dev/dri/renderD*` are 0666 → no video/render group plumbing needed, even for DynamicUser services.
- ROCm ≥7.x has **native gfx1201** kernels (no `HSA_OVERRIDE_GFX_VERSION`); `llama-cpp-rocm` is binary-cached.
- Re-benchmark after `nix flake update` (protocol in docs/llm.md; follow-ups in TODO.md).
- Free VRAM before gaming: `systemctl restart llama-cpp` (router unloads until next request).

## nixpkgs wiring (single source since 2026-07-03)

Hosts build **entirely** from `inputs.nixpkgs` (Den does `pkgs = inputs.nixpkgs.legacyPackages`, and nixosSystem modules
come from the same node). `nixpkgs` and `nixpkgs-unstable` both point at the **FlakeHub weekly**
(`DeterminateSystems/nixpkgs-weekly` — nixpkgs-unstable snapshots with a supply-chain cooldown), so host
modules/packages and every input's `follows` come from one source; the host runs a 26.11-pre release string. Before
2026-07-03 `nixpkgs` was 26.05-chilled, which made host _module shapes_ stable-era while docs/search showed unstable —
that skew is gone. Two gotchas:

- flake-file cannot render a root-level `follows` (`url` is non-nullable), so the weekly URL is **duplicated** in
  `flake-file.nix`; a full `nix flake update` keeps both nodes in lockstep — never update one alone.
- search.nixos.org's "unstable" index lags the FlakeHub weekly; verify option shapes against the locked store path
  (`nix eval --raw --impure --expr 'toString (builtins.getFlake "/path").inputs.nixpkgs'`) when it matters.

## Native build toolchain (`dev.tools.cc`)

`make`/`cc`/`g++`/`ar`/`pkg-config` reach df's PATH from `modules/den/aspects/dev/tools/cc.nix` (in `roles.dev` since
2026-09-02) — NixOS has no global build-essential, so anything that falls back to compiling from source
(`node-gyp rebuild` when no prebuilt binary matches, `pip install` of an sdist, …) fails with a bare `not found: make`
until this aspect is present. `roles.sandbox.dev` installs the same set on its own `nixos` side for guests.

- Prefer this over a one-off `nix shell nixpkgs#gnumake nixpkgs#gcc`: the compiled addon keeps an rpath into whichever
  gcc built it, and an ad-hoc shell's store path is not a GC root — the next `nix-collect-garbage -d` breaks the
  already-installed addon at runtime.
- It is a fallback, not a substitute for per-project toolchains in `devenv.nix`/`flake.nix`.

## Conventions

- treefmt: `nix flake check` runs a strict nixfmt; if `nix fmt` leaves `_:\n{}` expanded, hand-collapse to `_: {}` (what
  the check wants) and re-run `nix fmt`.
- Keep `nix flake update` as its own commit so it can be reverted independently.
