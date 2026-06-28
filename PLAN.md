# Den + MicroVM Migration Plan

> **NOTE (2026-06-28):** The Clan phase described below is retired. The repo has migrated off Clan to
> Den + sops-nix + deploy-rs; that migration (see `MIGRATION-STATUS.md`) replaced the clan.lol fleet step.
> The rest of this document is kept for historical context.

> Living plan for refactoring `donskifarrell/dotfiles` to the **Den** aspect-oriented
> pattern, adding **MicroVM.nix** dev guests, a remote IDE + Claude agent workflow, and
> a validation harness — then extending across the fleet with clan.lol.
>
> **How to use this file:** Work top to bottom. Each step has a _Goal_, _Sub-steps_,
> _How to test_, and _Done when_. Tick `- [ ]` boxes as you go. Do **one step per
> sitting**; commit at each green checkpoint. The Progress Log at the bottom is your
> resume point — write the date + commit hash there when you finish a step.
>
> **Golden rules**
>
> - Work on a `den` branch. `main` stays deployable the whole time.
> - **VM-first; abhaile last.** `abhaile` is your daily driver — it is the _last_ thing you
>   touch. Prove every role in a VM before flipping the real host: server/dev roles on `short`,
>   the **microvm-host + dev-guest stack on `short` with nested KVM**, and the desktop role in a
>   throwaway desktop-class VM via `nixos-rebuild build-vm`. Only refactor the real abhaile once
>   the Den config is stable in VMs.
> - Den is _additive_ — it coexists with your current `import-tree ./modules`. Migrate
>   aspect-by-aspect; never delete the old path until its replacement builds.
> - After every change: `nix flake check` must stay green before you commit.
> - Nix snippets below are **skeletons**. The **core API is verified** against den.denful.dev
>   (`den.aspects.*`, `den.hosts.<sys>.<name>.intoAttr`, `.microvm.guests`, `den.schema.host`
>   options all match). Den is still pre-1.0, so verify the **unconfirmed bits** — virtiofs share
>   syntax (docs only pin `microvm.sharedNixStore`) and the agenix wiring — against
>   `nix flake init -t github:denful/den#microvm` and the live docs as you implement them.
> - Den documentation is found at https://den.denful.dev but the github repos at github:denful/den will be useful too.

> **Current focus (start here).** Don't try to land the whole architecture at once. The first
> deliverable is **one machine (`short`) with one user (`df`)** composed from a _minimal_ set of
> Den aspects (core + a thin `role-server`), booting and deployable via clan. Everything below —
> multi-user, microvm guests, the desktop role, the fleet — is **iteration from that spine**. The
> reference for _how to organise the files_ is **`sini-nix`** (see "Repository layout" below); copy
> its layout and conventions, but **not** its fleet-scale machinery (environments, clusters,
> access-group ACLs, kubernetes) until you actually need more than one host/user.

---

## Target architecture (the end state)

| Host                  | Role                       | Class             | Hosts dev VMs?                  | Dev story                                         |
| --------------------- | -------------------------- | ----------------- | ------------------------------- | ------------------------------------------------- |
| **abhaile**           | Desktop: browse, game, GPU | `nixos`           | **Yes** (MicroVM host)          | Local guests on bridge + tailnet                  |
| **eachtrach**         | VPS: hosts public sites    | `nixos`           | Yes (or runs services directly) | Staging target + remote dev guest                 |
| **iompar** _(future)_ | M1 MacBook Pro             | `darwin`          | **No** (can't host KVM)         | Remote IDE into abhaile/VPS guests over Tailscale |
| **short** + QEMU VMs  | Throwaway test targets     | `nixos`           | n/a                             | Validation harness                                |
| **dev guests**        | Per-project dev sandboxes  | `nixos` (MicroVM) | n/a                             | git + go/ts + claude-code + `/shared` only        |

**Key decisions**

- **Den** owns config composition (aspects). **clan** stays as the deploy/secrets/inventory
  orchestrator. They layer cleanly: Den produces `nixosConfigurations`, clan deploys them.
- **MicroVM.nix** for lightweight declarative dev guests. **NixVirt** stays for heavy/GUI
  VMs (Windows 11). Don't migrate those.
- **Sandbox = VM boundary.** Guests mount exactly one host folder (`/shared`) via virtiofs.
  Never share `$HOME`. Claude runs _inside_ the guest and cannot reach desktop files.
- **Connectivity:** guests get a stable IP via host bridge (local) **and** join the tailnet
  (so iompar and the VPS can reach them by name). Reuse your existing `aon-tailnet` module.
- **IDE:** VS Code Remote-SSH or Zed remote connects to the guest over SSH. The Claude Code
  extension runs in the IDE but executes the `claude` binary inside the guest.
- **Secrets (three layers):** (1) **clan vars** (sops-nix backend) owns _machine-bound,
  generated_ secrets — host keys, per-node keys, emergency-access. (2) **agenix-rekey** owns
  _authored, shared_ secrets — DNS/ACME tokens, backup creds, shared CA — rekeyed to each host
  that includes them. (3) A **provider-agnostic runtime injection** layer feeds _dev-time_
  secrets (GH token, model API key) into guests at spin-up. No secrets baked into guest images;
  no secret provider client inside guests. The provider (1Password today) stays behind a single
  host-side script so it can be swapped later without touching any guest.

---

## Aspect taxonomy (how to carve the config)

You asked how to slice things. Use **two axes**: _concern_ aspects (the building blocks)
and _role_ aspects (bundles of concerns a host includes). Aspects compose via `.includes`
(a DAG) — a role is just an aspect that includes other aspects.

**Concern aspects** (one feature, all platforms — `nixos` / `darwin` / `homeManager`):

- `core` — nix settings, substituters, locale, base packages, shell
- `security` — ssh hardening, sudo, sops wiring, 1Password
- `networking` — base net, firewall defaults
- `tailscale` — wraps your existing clan tailscale module
- `desktop` — wayland/X, DE, fonts, audio (abhaile + iompar)
- `gpu` — drivers, CUDA/Vulkan (abhaile only)
- `gaming` — steam, gamemode, etc. (abhaile only)
- `dev-tools` — go, node/ts, git, direnv, editors, `claude-code` (guests + workstations)
- `syncthing` — wraps your existing clan syncthing module
- `observability` — journald/monitoring for servers (later)

**Role aspects** (include the concerns above):

- `role-workstation` → core, security, desktop, dev-tools, syncthing, tailscale
- `role-desktop-abhaile` → role-workstation + gpu + gaming + microvm-host
- `role-darwin-laptop` → core, security, desktop(darwin), dev-tools(darwin), tailscale
- `role-server` → core, security, networking, tailscale, observability
- `role-dev-guest` → core(min), dev-tools, sshd, shared-mount, (optional tailscale)

**Migration heuristic:** for each file under `modules/`, ask "what _concern_ is this, and
which _classes_ (nixos/darwin/hm) does it touch?" → that becomes one aspect with up to three
class blocks. Host-specific leftovers stay in a thin per-host aspect (`abhaile`, `iompar`…).

---

## Repository layout (modeled on sini-nix)

`sini-nix` (`/home/df/dev/sini-nix`) is the prime example of organising many
machines with Den. Adopt its layout under a single `modules/den/` tree, auto-imported by your
existing `import-tree ./modules`. Each file is a flake-parts module contributing to `den.*`.

```
modules/den/
  aspects/            # the building blocks, grouped by concern
    core/             #   one leaf file per feature: core/localization/i18n.nix, core/utils.nix …
    desktop/  apps/  services/  hardware/  virtualization/  secrets/
    roles/            # roles ARE aspects that `includes` other aspects: roles/server.nix …
  hosts/<name>.nix    # one file per host (short.nix) — host data + the host's aspect/includes
  users/<name>.nix    # one file per user (df.nix) — user aspect + registry (identity, uid, groups)
  schema/             # schema extensions (host.nix, user.nix) — add custom typed options here
  policies/           # host↔user resolution wiring (FLEET-SCALE — mostly skip for short+df)
  defaults.nix        # default host/user includes + which batteries every host gets
```

**Conventions to copy (verbatim patterns from sini-nix):**

- **Leaf aspect** = `den.aspects.<cat>.<name> = { nixos = {…}; homeManager = {…}; };`. Use the
  `os` class for config shared by nixos+darwin, `nixos` for Linux-only. Example:
  ```nix
  # modules/den/aspects/core/localization/i18n.nix
  { lib, ... }: {
    den.aspects.core.localization.i18n.nixos = _: {
      i18n.defaultLocale = "en_US.UTF-8";
      console.keyMap = "us";
    };
  }
  ```
- **Role aspect** = an aspect whose only job is to `includes` other aspects:
  ```nix
  # modules/den/aspects/roles/server.nix
  { den, ... }: {
    den.aspects.roles.server.includes = with den.aspects; [
      core.nix core.systemd.boot core.localization.i18n core.users core.security.openssh
      core.security.sudo core.network.networking secrets.agenix
      services.networking.tailscale
    ];
  }
  ```
- **Host file** = host data under `den.hosts.<sys>.<name>` + the host's composed aspect under
  `den.aspects.<name>` (its `includes` list; optional per-user sub-attrs add HM aspects scoped to
  that user on that host):
  ```nix
  # modules/den/hosts/short.nix
  { den, ... }: {
    den.hosts.x86_64-linux.short = {
      system-owner = "df";                 # binds df as the host's primary user
      # environment / settings / networking … (minimal for now)
    };
    den.aspects.short.includes = with den.aspects; [ roles.server ];
  }
  ```
- **User file** = user aspect + `den.users.registry.<name>` (identity, uid, groups, sshKeys):
  ```nix
  # modules/den/users/df.nix
  { den, ... }: {
    den.aspects.df.includes = [ den.batteries.host-aspects ];
    den.users.registry.df = {
      system.uid = 1000;
      groups = [ "wheel" ];
      identity = {
        displayName = "Donal Farrell";
        email = "donal@donalfarrell.com";
        sshKeys = [ { tag = "primary"; key = "ssh-ed25519 AAAA…"; } ];
      };
    };
  }
  ```

**What to borrow vs. skip (for the short + df MVP):**

| sini-nix piece                                                            | short + df now?                                                                                |
| ------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `aspects/` (core, roles, …) layout + leaf/role/host/user file conventions | **Borrow**                                                                                     |
| `hosts/<name>.nix`, `users/<name>.nix` one-file-each                      | **Borrow**                                                                                     |
| `schema/host.nix` for the odd custom option (e.g. `sshHostPubkey` in 2.3) | Borrow _as needed_                                                                             |
| `policies/` fleet/env/access-group resolution (`fleet.nix`, `users.nix`)  | **Skip** — rely on Den's built-in `host-to-users` + `system-owner`/`primary-user` for one user |
| `clusters/`, `environments/`, `groups/`, `kubernetes/`, `quirks/`         | **Skip** until multi-host                                                                      |
| Per-user-per-host aspect auto-include (`den.aspects.<host>.<user>`)       | Skip until >1 user shares a host                                                               |

> Verify the exact `system-owner`/`primary-user` binding and the `den.batteries.host-aspects`
> name against sini-nix + the 0.0 spike before relying on them — sini pins a specific Den branch
> (`github:sini/den/feat/…`), so option names there may lead the `denful/den` release you track.

---

## Phase 0 — Groundwork & safety nets

- [ ] **0.0 Den API spike (hard gate)**
  - _Goal:_ confirm the Den option surface this plan assumes _before_ building on it. The core
    paths are already verified against den.denful.dev (`den.aspects.*` with
    `includes`/`nixos`/`homeManager`/`darwin`; `den.hosts.<sys>.<name>.intoAttr = []`;
    `den.hosts.<sys>.<host>.microvm.guests`; `den.schema.host` option extension). The **unverified**
    bits are the ones the docs don't pin down — confirm these in a scratch flake.
  - _Sub-steps:_ `nix flake init -t github:denful/den#microvm` in a throwaway dir. Confirm: (a) the
    exact **virtiofs share** syntax (docs only document `microvm.sharedNixStore`); (b) how an aspect's
    `microvm.shares` / `microvm.interfaces` get forwarded to the host's guest runner; (c) the agenix
    schema-extension shape used in 2.3. Note any naming drift against the skeletons below.
  - _Test:_ the template's own `nix flake check` is green, and you can name the real options for
    shares + interfaces.
  - _Done when:_ the unverified option paths are confirmed (or the skeletons are corrected to match).

- [x] **0.1 Branch + task runner**
  - _Goal:_ safe workspace + memorable commands.
  - _Sub-steps:_ `git switch -c den`. Create a `justfile` (note: no `dev.sh` exists in the repo
    today) with targets: `check` (`nix flake check`), `fmt` (treefmt), `build-abhaile`,
    `deploy-short`, `test`. Drop the `dev.sh` references elsewhere in this plan in favour of `just`.
  - _Test:_ `just check` runs your existing checks.
  - _Done when:_ `den` branch exists and `just check` is green.

- [X ] **0.2 Fast test target**
  - _Goal:_ a throwaway VM you can rebuild/deploy in seconds for validation.
  - _Sub-steps:_ confirm `short` (192.168.122.217) boots and `clan machines update short`
    works. This is your integration target for the whole project.
  - _Test:_ `clan machines update short` succeeds; you can `ssh mise@short`.
  - _Done when:_ you can deploy to `short` on demand.

- [X ] **0.3 Snapshot current state**
  - _Goal:_ a known-good baseline to diff against.
  - _Sub-steps:_ `nix flake check` green on `main`; record `nixosConfigurations` list and
    the `flake.lock` hash in the Progress Log.
  - _Done when:_ baseline recorded.

## Phase 1 — Introduce Den (non-destructive)

- [ ] **1.1 Add Den input**
  - _Goal:_ Den available without touching existing modules.
  - _Sub-steps:_ add `den.url = "github:denful/den"` to inputs (follow `nixpkgs`/`flake-parts`).
    Import Den's flake-parts module alongside your current imports. Keep `import-tree ./modules`.
  - _Test:_ `nix flake check` still green — nothing should change yet.
  - _Done when:_ flake evaluates with Den present but unused.

- [ ] **1.2 Prove the pipeline with one trivial aspect**
  - _Goal:_ confirm Den → nixosConfiguration works end to end.
  - _Sub-steps:_ pick something harmless (e.g. fonts, or a shell alias). Express it as a Den
    aspect (using the sini-nix layout) and include it on `short` only. Skeleton:
    ```nix
    # modules/den/aspects/desktop/fonts.nix  (flake-parts module; Den reads den.aspects.*)
    { ... }: {
      den.aspects.desktop.fonts.nixos.fonts.packages = [ /* ... */ ];
    }
    ```
  - _Test:_ `nixos-rebuild build --flake .#short`; diff the closure — only fonts changed.
    Then `clan machines update short` and verify on the box.
  - _Done when:_ a Den-defined aspect is live on `short`.

- [ ] **1.3 MVP: `short` + `df` fully composed from minimal Den (the spine)**
  - _Goal:_ the **current-focus deliverable** — `short` boots and deploys entirely from a minimal
    Den composition, with `df` as its single user. Everything after this is iteration.
  - _Sub-steps (follow the "Repository layout" conventions):_
    1. Create `modules/den/users/df.nix` — `den.users.registry.df` (uid, `wheel`, identity,
       ssh key) + `den.aspects.df.includes = [ den.batteries.host-aspects ]`.
    2. Create just enough leaf aspects under `modules/den/aspects/core/` to boot a server (nix
       settings, locale, openssh, sudo, users, networking) — port them from your existing
       `modules/system/*` one concern at a time.
    3. Create `modules/den/aspects/roles/server.nix` that `includes` those core aspects.
    4. Create `modules/den/hosts/short.nix` — `den.hosts.x86_64-linux.short` with
       `system-owner = "df"`, and `den.aspects.short.includes = [ roles.server ]`.
    5. Rely on Den's built-in host→user resolution (`system-owner`/`primary-user`) — **do not**
       copy sini's `policies/` fleet machinery for one user.
  - _Test:_ `nixos-rebuild build --flake .#short` builds; closure diff vs. the legacy `short` is
    only intended changes. `clan machines update short`; `ssh df@short` works; `id df` shows the
    expected groups; `nix flake check` green.
  - _Done when:_ `short` is composed from Den aspects with `df` as user, deployable via clan, and
    the old per-host `machines/short` module is reduced to the irreducible host bits.

## Phase 2 — Carve config into aspects (iterate from the MVP)

> Do this incrementally. One concern per sitting. After each, build the affected hosts and
> keep `nix flake check` green. Use the taxonomy table above as the checklist. Each new concern
> is a new leaf file under `modules/den/aspects/<cat>/` that a role `includes` — same pattern as
> the 1.3 MVP, just more aspects.

- [ ] **2.1 `core` aspect** (nix settings, locale, base pkgs, shell) — migrate, build all hosts.
- [ ] **2.2 `security` aspect** (ssh, sudo, sops, 1Password).
- [ ] **2.3 Secrets split (clan vars + agenix-rekey)** — _parallel / optional; not on the
      dev-guest critical path. This is a large, orthogonal migration: do it alongside the other
      work, but don't let it block reaching a bootable dev guest (Phase 4)._
  - _Goal:_ move hand-authored shared secrets out of ad-hoc sops-nix into agenix-rekey, while
    clan vars keeps machine-bound generated secrets. They coexist: sops-nix decrypts to
    `/run/secrets`, agenix to `/run/agenix`; the only shared resource is each host's age
    recipient. **Dividing rule:** _machine generates it_ → clan vars; _you author it and share
    it_ → agenix-rekey.
  - _Decisions (lock these in):_
    - `storageMode = "local"` — rekeyed outputs are host-encrypted and committed, so CI and
      test VMs build **purely** without your master key. (`derivation` mode would block
      CI-driven validation in Phase 6.)
    - **Master identity** = an age identity pulled from your secret provider at rekey time
      (1Password today via `op read`). It's only needed on your machine when running
      `agenix edit`/`rekey`, never on hosts. A FIDO2/YubiKey is the optional comfort upgrade
      (enables lazy rekeying / no passphrase re-prompt).
    - **Host recipients** via Den schema, not per-host boilerplate.
  - _Sub-steps:_
    1. Add inputs `agenix` + `agenix-rekey` (override `agenix-rekey.inputs.nixpkgs.follows`).
       Import the flake-parts `agenix-rekey` module at top level; add the `agenix` wrapper to
       `devShells.default` next to `clan-cli`.
    2. Extend `den.schema.host` with `sshHostPubkey`; set it per persistent host (abhaile,
       eachtrach, iompar, short) to that host's ed25519 SSH pubkey — the same key clan deploys,
       so both systems agree on the recipient.
    3. Write an `agenix` aspect; roles `.include` it. Skeleton:
       ```nix
       # modules/aspects/agenix.nix  (verify option names vs current agenix-rekey)
       { inputs, lib, ... }: {
         den.schema.host.options.sshHostPubkey =
           lib.mkOption { type = lib.types.str; default = ""; };
         den.aspects.agenix.nixos = { host, ... }: {
           imports = [
             inputs.agenix.nixosModules.default
             inputs.agenix-rekey.nixosModules.default
           ];
           age.rekey = {
             storageMode = "local";
             localStorageDir = ./. + "/secrets/rekeyed/${host.name}";
             hostPubkey = host.sshHostPubkey;
             masterIdentities = [ /* op-read age identity path */ ];
           };
         };
       }
       ```
    4. Inventory your current sops-nix secrets. For each, classify: machine-bound → leave to
       clan vars; authored+shared → `agenix edit secrets/<name>.age`, then declare
       `age.secrets.<name>.rekeyFile` in the aspect that needs it and `.include` on its roles.
    5. `agenix rekey`, commit the rekeyed outputs, deploy `short`, confirm the secret lands at
       `/run/agenix/<name>` and the consuming service reads it.
  - _Test:_ `short` builds purely (no master key in env), secret present at runtime, clan vars
    secrets still intact at `/run/secrets`.
  - _Done when:_ every hand-authored shared secret is in agenix-rekey; sops-nix is used **only**
    as clan's machine-secret backend; `nix flake check` green.

- [ ] **2.4 `networking` + `tailscale` aspects** (wrap existing clan modules as aspects).
- [ ] **2.5 `dev-tools` aspect** (go, node/ts, git, direnv, editors, claude-code). This one
      feeds both workstations and dev guests — design it to be class-agnostic where possible.
- [ ] **2.6 `syncthing` aspect** (wrap existing clan instance).
- [ ] **2.7 Define `role-*` aspects** that `.includes` the concerns. Repoint `short` to a role.
  - _Test (each):_ affected hosts build identically or with only the intended diff.
  - _Phase done when:_ `short` is fully Den-composed and the old per-host module is empty.

## Phase 3 — Build the desktop role (validate in a VM, don't flip abhaile yet)

> **VM-first:** this phase _composes_ the desktop role and proves it in a throwaway
> desktop-class VM (`nixos-rebuild build-vm`). The real abhaile is **not** switched here — that
> happens in **6.6**, after both the desktop role _and_ the microvm/dev-guest stack are green in
> VMs. GPU passthrough and gaming can only be fully exercised on real hardware; in the VM you're
> validating that the role _evaluates and boots_ under software/virtio-gpu rendering.

- [ ] **3.1 `desktop` + `gpu` + `gaming` aspects** — migrate abhaile's DE, GPU, Steam, etc.
- [ ] **3.2 Thin `abhaile` host aspect** for the genuinely host-specific bits (hardware-config,
      disk, hostId).
- [ ] **3.3 Compose `role-desktop-abhaile`** = role-workstation + gpu + gaming.
  - _Sub-steps:_ also declare a desktop-class test host (e.g. `abhaile-vm`) that includes the same
    role minus the bare-metal bits (real GPU passthrough, facter hardware) so it can run under QEMU.
  - _Test:_ `nixos-rebuild build --flake .#abhaile` — closure diff vs. baseline is only refactor
    noise (build only, **do not switch**). Then `nixos-rebuild build-vm --flake .#abhaile-vm` and
    **boot the VM**: DE comes up, login works, dev-tools present.
  - _Done when:_ the desktop role builds for abhaile and boots cleanly in the VM. (The real abhaile
    switch is deferred to **6.6**.)

## Phase 4 — MicroVM host + first dev guest (proven on `short`, not abhaile)

> **VM-first:** the entire microvm-host + dev-guest stack is validated on **`short` with nested
> KVM enabled** — abhaile is not made a microvm host until **6.6**. This is the heart of the
> "iterate in a VM until the Den config is stable" goal: you can build, boot, break, and rebuild
> the guest pattern on a throwaway target without ever risking your daily driver.

- [ ] **4.1 Pull in the MicroVM template pattern**
  - _Goal:_ Den's microvm schema + policies in your repo.
  - _Sub-steps:_ `nix flake init -t github:denful/den#microvm` in a scratch dir; lift
    `microvm-integration.nix` (schema extensions + the host→microvm-host→guest policies) and
    `microvm-runners.nix` into your `modules/`. Add `microvm.url = "github:microvm-nix/microvm.nix"`.
  - _Test:_ `nix flake check` green; the new policies evaluate.
  - _Done when:_ Den knows about `host.microvm.guests`.

- [ ] **4.2 Make `short` a MicroVM host (nested KVM)**
  - _Sub-steps:_ enable **nested virtualization** so a QEMU guest (`short`) can itself run KVM
    guests — set `boot.extraModprobeConfig = "options kvm_intel nested=1";` (or `kvm_amd`) on the
    QEMU _host_ (abhaile), and confirm `cat /sys/module/kvm_intel/parameters/nested` reads `Y`.
    Write a reusable `microvm-host` aspect and include it on `short`'s role; set up a host
    **bridge** (e.g. `br0`) so guests get routable IPs.
    ```nix
    den.aspects.microvm-host.nixos = {
      microvm.host.enable = true;
      # bridge so guest taps are reachable from the host (and routable)
      networking.bridges.br0.interfaces = [];
      networking.firewall.trustedInterfaces = [ "br0" ];
    };
    ```
  - _Test:_ `clan machines update short`; `systemctl status microvm.target` is active inside
    `short`; `kvm-ok`/`/dev/kvm` present in the guest.
  - _Done when:_ `short` is a working microvm host with no guests yet. (abhaile gets this aspect in
    **6.6**, reusing the exact same module.)

- [ ] **4.3 Define `role-dev-guest` + first guest `dev`**
  - _Goal:_ a bootable dev sandbox with restricted sharing.
  - _Sub-steps:_ declare a guest Den host and attach it to **`short`** (the VM host — abhaile is
    re-targeted here only in 6.6). Skeleton:

    ```nix
    # the guest is a normal Den host; all aspects work inside it
    den.hosts.x86_64-linux.dev.intoAttr = [];
    den.hosts.x86_64-linux.short.microvm.guests = [
      den.hosts.x86_64-linux.dev
    ];

    den.aspects.role-dev-guest = {
      includes = [ /* core-min, dev-tools, sshd, tailscale(optional) */ ];
      nixos = { ... }: {
        services.openssh.enable = true;
        # ONE shared folder — never $HOME. Claude can only see this + guest fs.
        microvm.shares = [
          { source = "/home/df/shared/dev"; mountPoint = "/shared";
            tag = "shared-dev"; proto = "virtiofs"; }
          # runtime secrets: host-RAM tmpfs, read-only in guest, gone on shutdown.
          # Populated by the spin-up script (Phase 4.5). No provider client in guest.
          { source = "/run/devvm/dev"; mountPoint = "/run/host-secrets";
            tag = "host-secrets"; proto = "virtiofs"; }
        ];
        # tap onto the host bridge for reachable services
        microvm.interfaces = [{ type = "tap"; id = "vm-dev"; mac = "02:00:00:00:00:01"; }];
        microvm.autostart = true;
      };
      microvm.autostart = true;  # forwarded to host's microvm.vms.dev
    };
    ```

  - _Test:_ `nixos-rebuild build --flake .#abhaile` includes the guest; after deploy,
    `systemctl start microvm@dev` then `ssh df@<guest-ip>`. Inside: `ls /shared` works,
    `ls /home/df` on the host is **not** visible.
  - _Done when:_ the `dev` guest boots, SSH works, `/shared` is the only host window in.

- [ ] **4.4 Services reachable from the host network**
  - _Sub-steps:_ run a test service in the guest (e.g. `python -m http.server 8080`). Confirm
    `curl http://<guest-ip>:8080` from `short` and from abhaile over the bridge/LAN. If using
    Tailscale in the guest, confirm reachability by tailnet name from another node too.
  - _Done when:_ a guest service is reachable from the host + LAN/browser (+ tailnet).

- [ ] **4.5 Provider-agnostic secret injection (host-side)**
  - _Goal:_ feed dev-time secrets (GH token, model API key, Claude Code auth) into the guest at
    spin-up **without** a 1Password client in the guest and **without** coupling the guest to any
    provider — so you can switch away from 1Password later by editing one host-side script.
  - _Design:_ the guest's only contract is "secrets appear as files under `/run/host-secrets/`
    and an SSH agent is reachable at `$SSH_AUTH_SOCK`." Everything provider-specific lives on the
    host behind a single script.
  - _Sub-steps:_
    1. Write a host script `secret-provider <vm>` whose **only job** is to emit the needed
       values. Today it wraps `op read ...`; switching providers later (`pass`, `vault`, `sops`,
       a file) = rewrite this one script. Nothing else changes.
    2. At spin-up, write its output to the per-guest tmpfs dir (`/run/devvm/<vm>/`, mode 0500,
       root-owned, `tmpfs` so it's RAM-only) that virtiofs-shares read-only into the guest at
       `/run/host-secrets/`. Wipe the dir on guest stop.
    3. For git/SSH auth, **forward an SSH agent** into the guest scoped to just the git identity
       (1Password's SSH agent now; a plain `ssh-agent` with only the deploy key loaded later).
       The forwarded socket is the swappable boundary; the key never enters the guest.
    4. In the guest, a tiny unit/profile snippet reads `/run/host-secrets/*` into the env it
       needs (e.g. `ANTHROPIC_API_KEY`, `GH_TOKEN`). No provider logic in the guest.
  - _Security note:_ a forwarded agent can be _used_ by anything in the guest (incl. Claude) to
    auth as you — fine for git push/pull, but scope it to a single git identity rather than
    forwarding your whole agent, so the agent can't sign for unrelated hosts.
  - _Test:_ start the guest; `cat /run/host-secrets/gh_token` works inside; `op`/`1password` is
    **not** installed in the guest; `git -C /shared/<proj> fetch` succeeds via forwarded agent;
    after `systemctl stop microvm@dev`, `/run/devvm/dev` is empty.
  - _Done when:_ dev secrets reach the guest at runtime, nothing is baked, and the provider sits
    behind one replaceable host script.

## Phase 5 — Dev workflow polish

> During validation the `dev` guest lives on **`short`**, so the IDE/SSH targets point at the
> short-hosted guest (over the bridge or tailnet). After **6.6** the same guest moves to abhaile
> and these scripts/`~/.ssh/config` entries keep working unchanged — only the guest's host moves.

- [ ] **5.1 One-command spin-up/connect**
  - _Goal:_ `devvm dev` (or `just dev`) ensures the guest is up and drops you in.
  - _Sub-steps:_ small script: start `microvm@<name>` if not running, wait for SSH, then
    either open a shell or launch the IDE remote. Add an `~/.ssh/config` `Host dev` entry
    (HostName = guest IP/tailnet name, User = df) so `ssh dev` / IDE remote "just work."
    ```sh
    # devvm: bring up + connect
    name="${1:-dev}"
    systemctl is-active --quiet "microvm@$name" || sudo systemctl start "microvm@$name"
    until ssh -o ConnectTimeout=1 "$name" true 2>/dev/null; do sleep 1; done
    exec "${@:2:-$SHELL}"  # or: code --remote ssh-remote+$name /shared/<project>
    ```
  - _Done when:_ one command takes you from cold to connected.

- [ ] **5.2 IDE remote + Claude as the interface**
  - _Sub-steps:_ VS Code Remote-SSH (or Zed remote) to `dev`. Open the project from
    `/shared/<project>`. Install the Claude Code extension; point it at the in-guest `claude`
    binary (from your `claude-code` input, added via `dev-tools`). Auth (Claude Code + GH) comes
    from the Phase 4.5 injection layer — `/run/host-secrets/*` and the forwarded SSH agent — so
    no provider client or baked key lives in the guest.
  - _Test:_ edit/run code remotely; Claude agent runs commands inside the guest only; revoking
    the host secret (stop the guest) cleaves nothing decryptable behind.
  - _Done when:_ IDE + Claude operate fully inside the guest sandbox, secrets injected at runtime.

- [ ] **5.3 `dev.sh` / direnv inside the guest**
  - _Sub-steps:_ per-project `.envrc` (`use flake`) so go/node versions load on `cd`. Keep your
    `dev.sh` convention; have it shell into the nix devShell. Checkout flow: `git clone` from
    GitHub inside the guest into `/shared/<project>` (so artifacts persist on the host folder).
  - _Done when:_ entering a project auto-loads the toolchain; `dev.sh` works in-guest.

- [ ] **5.4 (Optional) Per-project ephemeral guests**
  - _Sub-steps:_ use **parametric aspects** to template a guest per project, or use the
    _runnable_ MicroVM pattern (`nix run .#dev-<project>`) for throwaway environments.
  - _Done when:_ you can stamp out a fresh isolated env per project.

## Phase 6 — Validation harness (the "test against VMs/VPS" goal)

- [ ] **6.1 Build-level checks (extend what you have)**
  - _Sub-steps:_ your `checks = buildChecks` already builds every host's `toplevel`. Extend it
    to also build MicroVM runners and guest configs so a broken guest fails `nix flake check`.
  - _Done when:_ `nix flake check` builds desktop + guests + servers.

- [ ] **6.2 Runtime checks with `nixosTest`**
  - _Goal:_ boot a VM in CI and assert behavior — your "validate changes against a test VM."
  - _Sub-steps:_ add a `nixos-lib.runTest` per concern. For the dev guest, assert: boots, sshd
    up, `go`/`node` present, `/shared` mounted, `$HOME` of host **not** present, a sample
    service answers on its port, `claude` binary exists.
    ```nix
    checks.x86_64-linux.dev-guest = pkgs.testers.runNixOSTest {
      name = "dev-guest";
      nodes.guest = { ... }: { imports = [ /* role-dev-guest */ ]; };
      testScript = ''
        guest.wait_for_unit("sshd.service")
        guest.succeed("test -d /shared")
        guest.succeed("command -v go && command -v node")
      '';
    };
    ```
  - _Done when:_ `nix flake check` runs boot tests for your key roles.

- [ ] **6.3 Integration target matrix (`short` + a second VM)**
  - _Sub-steps:_ keep `short` as the local integration box; add one more QEMU VM for a second
    arch/role if useful. A `just test-integration` target: `clan machines update short` then
    run smoke SSH assertions.
  - _Done when:_ one command deploys + smoke-tests a real VM.

- [ ] **6.4 VPS staging (eachtrach)**
  - _Sub-steps:_ re-enable `eachtrach` in the inventory (it's commented out). Treat it as
    _staging_ for the public-sites role: deploy there, run smoke tests, then promote.
  - _Done when:_ you can deploy to the VPS from a green check and verify the site responds.

- [ ] **6.5 CI**
  - _Sub-steps:_ GitHub Actions (or clan's test runner) on PR: `nix flake check` (treefmt +
    builds + nixosTests). Optionally a gated deploy-to-`short` job.
  - _Done when:_ PRs are gated on the harness.

- [ ] **6.6 Flip the real abhaile (the daily driver) — VM-validated gate**
  - _Goal:_ now that the desktop role boots in a VM (3.3) **and** the microvm-host + dev-guest
    stack is proven on `short` (Phase 4) and covered by nixosTests (6.2), switch the real abhaile
    onto Den in one deliberate step. This is the _only_ point where the daily driver changes.
  - _Pre-flight (all must be green):_ 3.3 desktop VM boots; 4.x dev-guest works on `short`; 6.1/6.2
    checks pass; nested KVM confirmed on abhaile (`/sys/module/kvm_intel/parameters/nested` = `Y`).
  - _Sub-steps:_ compose `role-desktop-abhaile` = role-workstation + gpu + gaming + **microvm-host**
    (the same aspect proven on `short`). Attach the `dev` guest to abhaile (move the `microvm.guests`
    line from `short` to `abhaile`, or include both). `nixos-rebuild build --flake .#abhaile` and
    closure-diff vs. baseline first; keep the current generation pinned in the bootloader for
    rollback.
  - _Test:_ `nh os switch .#abhaile`; DE + GPU + gaming work on real hardware, `microvm.target`
    active, `systemctl start microvm@dev` + `ssh dev` works, `/shared` is the only host window in.
  - _Done when:_ abhaile runs entirely from Den aspects, hosts the dev guest, and old desktop
    modules are removed. Roll back via the pinned generation if anything regresses.

## Phase 7 — Extend to the fleet (clan.lol + Darwin)

- [ ] **7.1 VPS as a full Den server** — compose `role-server`; move site-hosting into a
      `services-*` aspect; deploy via clan. Reuse tailscale exit-node setup you already have.
- [ ] **7.2 Darwin (iompar)** — build `role-darwin-laptop`; migrate Brewfile-managed bits into
      `darwin` class blocks of existing aspects (`dev-tools.darwin`, `desktop.darwin`). Mac's dev
      workflow = remote IDE into abhaile/VPS guests over tailnet (no local microvms).
- [ ] **7.3 Fleet patterns** — read Den's _Fleets & Multi-Host_ + clan inventory docs; use
      Den fleet/quirks for cross-host data (e.g. host discovery, shared CA, service mesh) layered
      on clan's inventory. Promote per-host tags to role aspects.
- [ ] **7.4 Retire legacy** — once every host is role-composed, delete dead modules and flip
      `main` to the Den layout.

---

## Decisions & open questions (fill in as you go)

- Guest networking: **bridge `br0`** (local, routable) + tailscale-in-guest (remote). Confirm
  whether you want guests on the LAN subnet or an isolated VM subnet with NAT.
- Shared-folder layout: single `/home/df/shared/<vm>` per guest? Or one shared root with
  per-project subdirs? (Affects how many virtiofs shares you declare.)
- Secrets layering (**resolved**): clan vars = machine-bound/generated; agenix-rekey
  (`storageMode = "local"`) = authored/shared; provider-agnostic runtime injection = dev guests.
  _Remaining:_ confirm agenix master-identity mechanism (op-read age identity vs. FIDO2 key),
  and decide whether `eachtrach`/`iompar` consume any agenix shared secrets or stay minimal.
- Does eachtrach run sites directly, or also host its own dev guest for remote work?
- Keep NixVirt for Windows 11; confirm no overlap with microvm bridge config.

## Glossary (your terms → Den terms)

- _"my modules/ files"_ → **aspects** (concern) and **role aspects** (bundles via `.includes`).
- _"per-host config"_ → a thin **host aspect** + the host's `.includes` list.
- _"a VM"_ → a **Den host** with `intoAttr = []`, attached to a host's `microvm.guests`.
- _"deploy"_ → still **clan** (`clan machines update <host>`).
- _"machine secret"_ → **clan vars** (sops backend). _"shared/authored secret"_ → **agenix-rekey**.
  _"dev-time secret"_ → **runtime injection** at `/run/host-secrets/` + forwarded SSH agent.
- _"validate"_ → `nix flake check` (builds + **nixosTest**) + clan deploy to `short`.

---

## Progress Log (your resume point)

> When you finish a step, add: `YYYY-MM-DD  <step id>  <commit hash>  notes`.

```
2025-__-__  0.1  ________  branch + justfile created
```
