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

## Machines

| Host      | System         | Role                                                                                                                                                                                 |
| --------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| abhaile   | x86_64-linux   | df's AMD desktop workstation (LUKS root, systemd-boot)                                                                                                                               |
| eachtrach | x86_64-linux   | (planned, TODO item 2) Hetzner x86 VPS — tailscale exit node + hosted apps; provisioned from a stock Ubuntu image via nixos-anywhere kexec; BIOS boot → needs grub, not systemd-boot |
| (macbook) | aarch64-darwin | (planned) df's MacBook Pro on nix-darwin + homebrew — inputs already kept for it                                                                                                     |

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
propagation, paseo) is tracked step by step with its verifications in [TASKS.md](TASKS.md); goals in [GOAL.md](GOAL.md).

Gotchas (easy to forget):

- **Nothing per-instance may enter the guest's `system.build.toplevel`** — that invariant is what lets every sandbox of
  a type share one built closure. Per-launch values (workdir, ports, cpu/mem, disk sizes, MAC, credential paths) may
  only touch `microvm.*` options that end on qemu's command line. The guest hostname is the static string `sandbox` for
  exactly this reason; the real name arrives as a boot credential.
- `scoite` is home-manager-installed: edits to `pkgs/by-name/scoite/package.nix` need a `nixos-rebuild switch` before
  they reach `$PATH`.
- **Two NICs.** `eth0` is SLIRP and keeps the default route: guests reach abhaile at `10.0.2.2` (llama-server :8080, omp
  auth-broker :8765, harmonia :5000 — unsigned by design). `eth1` is a tap on the host bridge `scoitebr0` (10.77.0.0/24,
  DHCP + `ip rule` beating tailscale's table 52) and exists so a guest has an inbound address and an mDNS name.
  Restarting `scoite-bridge.service` must never delete the bridge — that detaches every running guest's tap.
- **`scoite-<name>.local` resolves from abhaile** (guest `systemd-resolved` publishes, host avahi + `nssmdns4` resolve).
  Nothing is reachable from the LAN unless you say so: `scoite expose --lan <port>` installs an iptables DNAT via the
  root helper `scoite-lan`, recorded per instance and re-applied on start. With a tailscale exit node selected, LAN
  reachability also needs `--exit-node-allow-lan-access` (now set in `services/tailscale.nix`).
- Credentials reach the guest as qemu `fw_cfg` systemd credentials, never through `/nix/store`: pass **string** paths,
  never Nix path literals, or the file gets copied into the world-readable store at eval time.
- Git auth in a guest = **forwarded ssh-agent + `~/.ssh/sshconfig.local`**. The alias config and the _public_ halves of
  the keys it names ride in as the `SSH_CONF` credential; private keys never do. A remote using a bare `github.com` URL
  works either way — one using `<acct>.github.com` needs that config.
- Running sandboxes don't pick up _system_ config changes — stop and start them. **Host identity is the exception**:
  `scoite creds [<name>|--all]` re-pushes agent.env, ssh config, gitconfig and omp config into a _running_ guest, and
  runs on every `scoite ssh` plus a 10-min host timer. New guest shells only.
- Guest-side installers called from systemd units need **absolute store paths** — a unit's PATH has no
  `/run/current-system/sw/bin`, and the failure is a swallowed "command not found" at boot while the push path works.
- omp in a guest never holds an Anthropic token — it asks the host broker per request, and the broker refreshes. Two
  things still break it: a rotated **bearer** token (fix: `scoite creds`), and a definitive `invalid_grant` refresh
  failure, after which the broker **disables** the credential (fix: `omp auth-broker login anthropic` on the host). The
  `omp-broker-check` timer now notifies on both, plus duplicate credential rows. A broker restart after a login is NOT
  needed on omp ≥17.4.2.
- Model ids/context sizes are generated for both llama-server and every guest's omp `models.yml` from
  `modules/den/aspects/services/_llm-models.nix` — edit that, not the two consumers.
- herdr decides a pane's cwd (`terminal.new_cwd`, set to `/workspace` for the `dev` tier) and persists its session in
  the guest's home; an old `session.json` keeps old panes.

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

## Conventions

- treefmt: `nix flake check` runs a strict nixfmt; if `nix fmt` leaves `_:\n{}` expanded, hand-collapse to `_: {}` (what
  the check wants) and re-run `nix fmt`.
- Keep `nix flake update` as its own commit so it can be reverted independently.
