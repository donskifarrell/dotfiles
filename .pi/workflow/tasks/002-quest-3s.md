# Quest 3S on abhaile

- Owner: parent; status: implementation complete, evaluated/built/reviewed; activation and headset tests pending user.
- Scope agreed: Linux PC VR first; ALVR over Wi-Fi and USB; Looking Glass development setup documented/deferred (no
  install, Windows VM, GPU passthrough or boot changes); llama.cpp manual-start only.
- Live state: inference stopped with prior user authority. Rechecked `systemctl is-active llama-cpp.service` =
  `inactive`, `is-enabled` = `enabled` (old live configuration). No switch/deploy/reboot performed; boot enablement
  changes only when the user activates the new configuration.
- Git: no staging/commits authorized or performed. Initial tree clean except this untracked checkpoint. All Nix
  changes modify tracked files, so the normal git flake includes them; new Markdown does not affect imports. No
  unsafe whole-worktree `path:` copy needed.

## Implemented

- `modules/den/hosts/abhaile.nix`: includes `apps.gaming.steam` and `apps.gaming.alvr` on abhaile only.
- `modules/den/aspects/gaming/steam.nix`: drops unused Remote Play/dedicated-server firewall openings and stray comment.
  Existing Steam/gamescope/gamemode settings retained. ALVR opens TCP+UDP 9943/9944 via its existing aspect/module.
- `modules/den/aspects/services/llm.nix`: retains installed llama-cpp unit/API config, forces `wantedBy = [ ]` for manual
  start/stop. No runtime wrapper or automatic GPU arbitration added.
- USB plan corrected against locked code: `programs.adb` was removed (`nixos/modules/rename.nix:65–72`); systemd ≥258
  grants active local users access through uaccess. `dev.apps` already installs android-tools for df. No duplicate
  package, removed option or adbusers group added. Running systemd 261 and its `70-uaccess.rules` inspected.
- `docs/vr.md`: activation, matching ALVR/APK (locked 20.14.1), developer/debug authorization, SteamVR vrmonitor launch
  workaround, Wi-Fi/native USB, GPU/encoder/audio checks, video limits, manual acceptance, declarative regression check,
  and Looking Glass development prerequisites/deferral. ALVR v20.14.1 `get_adb_path` checked: prefers PATH adb.
- `AGENTS.md`, `docs/llm.md`: link VR guide and replace restart-before-gaming advice with explicit stop/start.
- `TODO.md` item 12: Steam/ALVR no longer orphaned; prioritized pending activation/headset/video/Looking Glass table.

## Verification / known-good

- Focused `nix eval --json .#nixosConfigurations.abhaile.config --apply ...` assertions passed: Steam/ALVR enabled;
  Steam Remote Play and dedicated-server firewall false; TCP+UDP 9943/9944 present; df home packages include
  android-tools; llama service enabled but wantedBy/requiredBy empty.
- Additional eval inspected generated llama unit: no Install/boot attachment; scan of all other generated systemd
  unit texts for `llama-cpp.service` returned `reverseReferences = []`.
- `nix build --no-link --print-out-paths .#nixosConfigurations.abhaile.config.system.build.toplevel` succeeded:
  `/nix/store/s63i4vldghj01jmjy3a7kls38bi6ygqv-nixos-system-abhaile-26.11.20260913.ef34387`.
  Built system-units contains only the llama-cpp.service symlink, no wants/requires symlink for it. An offline
  `systemctl --root=<toplevel> is-enabled` probe returned `not-found` (the store closure is not an installed root);
  this is not runtime enablement evidence. Unit text and actual output symlinks were inspected directly instead.
- `git diff --check` and `nixfmt --check` on the three modified Nix files passed. Markdown is excluded by treefmt.
- Existing evaluation warning: `stdenv.isLinux is deprecated`; no unrelated cleanup performed.
- Independent review: `quest-review`, anthropic/claude-sonnet-5, high thinking (other provider than parent). Fresh
  admission was allowed+known (66% remaining observed), startup ready and review completed. Verdict: Looks good, Ship;
  no correctness/security/data-loss blockers. Reviewer checked connected includes, locked modules, firewall and USB
  policy, no unwanted passthrough/installation changes. It did not duplicate the parent build or headset tests.
- Reviewer handle: pane `w1:p2`, tab `w1:t2`, Pi session `02d665c0-6aa8-4ef4-b14c-e394e8a0f809` (completed; own tab
  closed after saving evidence).

## Follow-up: first SteamVR launch (2026-10-17)

- User activated the built configuration: `/run/current-system` resolves to the known-good toplevel above.
- Live firewall active; `sudo -n iptables -S nixos-fw` and `ip6tables -S nixos-fw` both accept TCP+UDP 9943/9944.
  ALVR's in-app firewall command success unknown/unneeded. No live firewall modifications performed by agent.
- llama-cpp live state `inactive`, unit file state `linked` (not enabled). Documentation corrected to allow linked.
- SteamVR `vrstartup-linux.txt:20–22`: `pkexec must be setuid root`, then missing cap_sys_nice and setup incomplete.
  Read installed vrsetup.sh: uses `pkexec setcap CAP_SYS_NICE=eip` on vrcompositor-launcher. NixOS VR wiki documents
  additional bubblewrap capability restriction; do not apply unsafe permission/kernel/bwrap workarounds by default.
- vrmonitor.sh exists. Logs show the old `vrstartup.sh` path; no vrmonitor.sh match in gameprocess log. ALVR external
  driver is registered in openvrpaths.vrpath, but no ALVR load found in examined vrserver logs. Next user action:
  set exact SteamVR launch option shown in docs/vr.md, close/relaunch SteamVR through ALVR, then retry pairing/stream.
- Updated docs/vr.md startup warning notes and AGENTS.md pointer. No outside-repo writes or privilege changes.
  Existing staged changes belong to user; index left untouched. Streaming/encoder/audio still unverified.

## Follow-up: ALVR dashboard bind conflict (2026-10-17)

- Confirmed QEMU pid 743866 owns `127.106.26.1:8082` (also 8083/8084), conflicting with ALVR's wildcard bind.
  scoite intentionally forwards 8080–8089 per guest. VM left running; no changes to scoite or firewall.
- User explicitly authorized backing up/editing `~/.config/alvr/session.json` outside repo after closing apps.
  Confirmed no alvr_dashboard/vrserver/vrmonitor processes before edit. Changed only
  `session_settings.connection.web_server_port` from 8082 to 18082. Backup (0600):
  `/home/df/.config/alvr/session.json.bak.XdBSGdfc`.
- Regression check passed: both JSON documents parse; old with just that one field changed equals new; temporary
  socket bind to `0.0.0.0:18082` succeeds. Source v20.14.1 settings.rs/data_sources.rs confirms shared port setting.
- docs/vr.md + AGENTS.md record local mutable port and why. Next user action: open ALVR, launch SteamVR again;
  actual ALVR/SteamVR streaming still not retested by agent.

## Follow-up: black headset screen / compositor crash (2026-10-17)

- Headset trusted and session connection_state `Streaming`; ALVR driver now loads in vrserver. RX 9070/RADV selected;
  inference inactive; dashboard port 18082 works. No compositor process remains after launch.
- `coredumpctl list --since '2026-10-17 15:18:00'`: repeated vrcompositor.real SIGSEGVs, last pid 1224007 at 15:24:30.
  First crashing thread 1224038 has instruction pointer 0, called from vrcompositor.real+0x403ff2; kernel logs confirm
  RenderThread segfaults. No demonstrated causal link to CAP_SYS_NICE warnings; no priority/security changes made.
- ALVR extra.patches.linux_async_compute and linux_async_reprojection already false; H.264 selected. Current compositor
  logs say Vulkan wait-for-present-ID support will be used; installed binary contains disableLinuxWaitForPresent.
- Bounded experiment APPLIED after user authorized outside-repo edit and confirmed apps closed; rechecked no
  alvr_dashboard/vrserver/vrmonitor/vrcompositor processes. Added `steamvr.disableLinuxWaitForPresent = true` to
  `/home/df/.local/share/Steam/config/steamvr.vrsettings`. Backup (0600):
  `/home/df/.local/share/Steam/config/steamvr.vrsettings.bak.wdimkIyK`.
- Regression check passed: old/new JSON parse and semantic diff is exactly that one added key. No reboot/rebuild,
  drivers, privileges or firewall changes. User subsequently reports the default screen is visible in the headset.
  Initial rendering restored; no long-running/game/video/transport acceptance yet. Agent has not rechecked compositor
  lifetime or disabled-feature log after restart. User now wants free/open-source video streaming options.
- Source https://github.com/ValveSoftware/SteamVR-for-Linux/issues/948 describes AMD present-wait problems, but later
  comments retract a universal fix and concern a wired Index; this is a reversible test, not a proven match. ALVR
  issue 3233's async workaround is already off here. Do not randomly change several settings or install patches.

## Sources / remaining hazards / next action

- Re-fetched upstream ALVR installation, Linux troubleshooting and wired setup wiki pages; docs/vr.md links them.
  USB source: https://github.com/alvr-org/ALVR/blob/v20.14.1/alvr/adb/src/commands.rs .
- Looking Glass earlier research: https://looking-glass.io/downloads and development requirements
  https://looking-glass.io/docs/B7-829-cdba29f2/requirements/ . Observed build is historical context, not an install pin;
  recheck/match all components when a separate Windows VM/GPU design is authorized.
- Not tested: headset pairing, Wi-Fi/USB stream, SteamVR, APK installation, RX 9070 encoding, game/video/audio/mic,
  manual llama start/reboot behavior after activation. No full `nix flake check` (focused eval and host build done).
- Next: user applies `sudo nixos-rebuild switch --flake .#abhaile` when ready, then follows docs/vr.md manual checks.
  Until activation, the old enabled llama service can still start at reboot. ALVR opens LAN ports when applied; use
  trusted networks, trust only the owned headset, no router forwards. Keep RX 9070 on Linux; no VFIO under this task.
