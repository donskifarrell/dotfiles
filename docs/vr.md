# Quest 3S PC VR on abhaile

For local 180°/360°/stereo video files, use the separate [direct-to-Quest video setup](quest-video.md) (miniserve +
Wolvic; no SteamVR/ALVR required). It is prepared but not activated.

Linux PC VR uses **SteamVR + ALVR**, over Wi-Fi or USB. The RX 9070 stays attached to Linux. This is not Meta Quest
Link/Air Link (Windows software), and a USB cable still carries an encoded ALVR stream, not DisplayPort video.

Config: `modules/den/hosts/abhaile.nix` includes `apps.gaming.steam` and `apps.gaming.alvr` on this host only. ALVR opens
TCP/UDP 9943 and 9944 through the host firewall; Steam Remote Play and dedicated-server exceptions stay off. Only run
ALVR on trusted networks; do not forward these ports on the router. Trust only your own headset in its dashboard.

## Apply the host configuration

No activation is performed by the implementation task. When ready, from this repository:

```sh
sudo nixos-rebuild switch --flake .#abhaile
systemctl is-active llama-cpp.service
systemctl is-enabled llama-cpp.service
```

Inference should be **inactive** and have no boot enablement (`linked` on the activated host, or `static`; not
`enabled`). These status commands can return nonzero for inactive/static units. It was stopped before implementation, but that alone does not survive a reboot
until this config is applied. If it was manually started again, stop it with `sudo systemctl stop llama-cpp`.
`sudo systemctl start llama-cpp` opts back in; **restart is not a gaming guard** because the next API request can load a
model. See [llm.md](llm.md). No GPU/bootloader/VFIO changes are part of this setup.

`adb` already comes from df's `dev.apps` home packages. This nixpkgs removed `programs.adb`: systemd ≥258 grants USB
access through uaccess to the active local session. No `adbusers` membership/new group login is needed. Run adb and
ALVR as df from the local desktop, not as root or an SSH-only session. Replug the cable after activation if needed.

## First launch and headset APK

1. Open Steam as df, sign in, install **SteamVR** from the library/tools, launch it once, then close it.
2. In SteamVR → Properties → General → Launch Options, apply ALVR's current mandatory Linux runtime workaround:

   ```text
   ~/.local/share/Steam/steamapps/common/SteamVR/bin/vrmonitor.sh %command%
   ```

   If Steam uses another library, substitute its actual path (Steam → Settings → Storage). A wrong path prevents
   SteamVR from starting. Do not copy a distro-specific `/usr` path into NixOS or run downloaded fix scripts blindly.
3. Run `alvr_dashboard` (or ALVR from the application menu). Use the packaged dashboard, not a second downloaded PC
   streamer. Let it register its SteamVR driver; the Installation tab also has **Register ALVR driver**. A first blank
   SteamVR run may need closing/relaunching after registration. Start Steam before starting SteamVR through ALVR.
4. Check the PC version in the dashboard, or from this repo:

   ```sh
   nix eval --raw .#nixosConfigurations.abhaile.pkgs.alvr.version
   ```

   The current lock packages **20.14.1**. Download the matching `alvr_client_android.apk` from the
   [official release with that version](https://github.com/alvr-org/ALVR/releases/tag/v20.14.1), not whichever release
   happens to be newest. Recheck the version after a flake update; keep PC and headset on the same release/channel.
5. Enable headset Developer Mode through Meta's current account/device setup flow (may require developer account
   verification); enable USB debugging. Connect a data-capable cable, wear/unlock the headset, and approve **Allow USB
   debugging?** for this computer. Only persist authorization for a computer you trust.
6. Confirm `adb devices -l` shows the headset as `device`, not `unauthorized` or `no permissions`. Install the reviewed,
   official matching APK from its download directory:

   ```sh
   adb install -r ./alvr_client_android.apk
   ```

   If more than one Android device is attached, use `adb -s <headset-serial> install -r ...` and target that serial in
   other adb commands. Launch ALVR from the headset's **Unknown Sources** apps. If authorization is missing, check the
   in-headset prompt, developer/debugging settings and cable; do not make USB world-writable or expose network adb.

## Startup warnings on NixOS

- **ALVR vrmonitor reminder:** set SteamVR's launch options to the exact absolute path shown by ALVR, followed by
  `%command%`, then fully close SteamVR and relaunch through ALVR with Steam open. The file exists on abhaile at
  `/home/df/.local/share/Steam/steamapps/common/SteamVR/bin/vrmonitor.sh`. A driver registration alone does not apply
  this launch option; the normal `vrstartup.sh` path still uses Steam's incompatible runtime setup.
- **Panic binding `0.0.0.0:8082` / address in use:** scoite forwards 8080–8089 on each guest's loopback address;
  a wildcard ALVR bind still conflicts with those. Keep the VM running and change ALVR Settings → Connection →
  **Web Server Port** (advanced settings) to **18082**, then restart ALVR and SteamVR. This was applied locally in
  `~/.config/alvr/session.json` (`session_settings.connection.web_server_port`) with both apps closed; it is mutable
  ALVR state, not a Nix option. Port 18082 was bind-tested free. Do not substitute 8083/8084 (also forwarded), change
  stream ports 9943/9944 or open the dashboard port in the firewall. Recheck for conflicts if changing it again.
- **Firewall setup button:** skip it on NixOS; the declarative module owns the rules. On 2026-10-17 the active IPv4
  and IPv6 `nixos-fw` chains were inspected: TCP+UDP 9943/9944 were accepted. This proves the host rules exist, not
  end-to-end Wi-Fi connectivity or that ALVR's own firewall command succeeded.
- **Superuser / setup incomplete:** the observed `logs/vrstartup-linux.txt` says `pkexec must be setuid root`, then
  `readback of vrcompositor-launcher shows still lacking cap_sys_nice`. Valve's `vrsetup.sh` tries to grant the
  compositor launcher `CAP_SYS_NICE` for high-priority scheduling. Steam's bubblewrap/FHS environment on NixOS also
  prevents normal use of these privileges; accepting the dialog does not fix that. Apply the vrmonitor launch option
  first (it directly launches the monitor rather than running `vrstartup.sh`'s setup helper). Do not run Steam/ALVR
  as root, chmod pkexec, or patch kernel/bubblewrap protections just to silence the warning. SteamVR may operate
  without the privilege, but asynchronous reprojection can be unavailable; a real stream is still required to assess
  usability. See the [NixOS VR capability limitation](https://wiki.nixos.org/wiki/VR#SteamVR).

### Black screen with a crashing compositor — initial rendering restored

On 2026-10-17 ALVR reported `Streaming`, but `vrcompositor.real` repeatedly SIGSEGVed in RenderThread just after
startup (RX 9070/RADV). ALVR's async compute/reprojection settings were already off. With apps closed and settings
backed up, added `"disableLinuxWaitForPresent": true` inside `"steamvr"` in
`~/.local/share/Steam/config/steamvr.vrsettings`. JSON validation confirmed no other setting changed.
The user reported seeing the default screen after this change. This is initial rendering confirmation, not a
long-running/game/video test or proof of the underlying crash cause. If the problem returns, check compositor
survival and the new log's wait-for-present status before changing more settings. To revert, remove just this added
key with SteamVR closed.
The [upstream AMD report](https://github.com/ValveSoftware/SteamVR-for-Linux/issues/948) concerns a different headset
and later comments question the workaround; do not treat it as proof of this crash's cause.

## Wi-Fi

- Prefer PC → Ethernet → router/AP, headset on a nearby uncongested 5 GHz Wi-Fi network. Avoid guest Wi-Fi/client
  isolation: the headset must reach the PC. No internet-facing router port forwards or extra streaming daemon needed.
- Disable **Wired Connection** in ALVR's Devices tab for this test. Start ALVR on the headset, keep its display awake,
  and **Trust** its entry in the PC dashboard. If discovery fails, check both devices' LAN addresses, AP isolation and
  the host firewall; use the headset's actual LAN address for manual pairing if needed.
- If abhaile is using its Tailscale exit node, retain LAN access (`--exit-node-allow-lan-access`, already configured).
  Start at ALVR defaults/modest resolution and bitrate; establish a stable stream before increasing quality.

## USB (native wired mode)

ALVR ≥20.12 supports USB from the dashboard; do not start with deprecated manual `adb forward` scripts.

1. Connect a data-capable USB 3 cable/port, authorize debugging, and verify `adb devices -l` as above.
2. Enable **Wired Connection** in ALVR → Devices. For a GitHub APK, set Connection → **Wired Client Type** to
   **Github** (also used for launcher-installed APKs).
3. Launch the headset client and SteamVR through the dashboard. Confirm the wired connection works; for an acceptance
   test, disable headset Wi-Fi temporarily to rule out an accidental wireless fallback. Restore Wi-Fi afterwards.
4. ALVR 20.14.1 tries `adb` on PATH before downloading platform-tools. If the shell check passes but the dashboard
   fails, launch `alvr_dashboard` from that same local terminal and inspect its log/PATH. Keep the NixOS adb rather
   than the downloader's generic Linux binary. Do not install a second unreviewed launcher or enable root/network adb.

USB does not guarantee the PC can keep the headset charged. Cable/controller/power delivery and encode/decode latency
still matter; this has not been measured on this headset.

## GPU, audio, games and video

- Use **Mesa RADV**, not AMDVLK. The existing AMD aspect enables graphics and 32-bit support. Check ALVR/SteamVR logs
  actually select **RX 9070**, not the Raphael iGPU; do not assume `DRI_PRIME=1` means the same GPU on every machine.
  Follow upstream hybrid-GPU guidance only if selection is wrong; no BIOS or GPU-binding changes are needed here.
- If encoding fails, inspect ALVR logs for VAAPI/codec errors before tuning bitrate. Start with a common supported
  codec (H.264); RX 9070 hardware encoding and this package/driver combination still need a real streaming test.
- Once connected, select **ALVR Audio** / **ALVR Microphone** in the desktop PipeWire device controls if sound/mic do
  not route automatically. These devices appear only while connected.
- Test a game with working Linux/Proton **VR** support; a desktop Proton rating alone is not a VR compatibility promise.
  For video, use a Linux-compatible SteamVR player that supports the file's projection (flat/180°/360°, mono/stereo).
  ALVR is the transport, not the player. No particular game, DRM service or video player has been verified here.

### Manual acceptance (record results here)

- [ ] After activation/reboot, llama-cpp remains inactive; a manual start serves `/v1/models`, then stop releases VRAM.
- [ ] SteamVR sees the headset and both controllers; both eyes render, tracking is stable, no persistent black screen.
- [ ] Wi-Fi stream works with USB disconnected; record codec, resolution, refresh rate, bitrate and latency/loss.
- [ ] Native USB stream works with headset Wi-Fi disabled; restore Wi-Fi after testing.
- [ ] Game launches; audio reaches headset and microphone reaches PC without feedback.
- [ ] VR video plays with correct projection/stereo; record player and settings. No codec/DRM guarantee until tested.

### Configuration regression check

From the repo, this checks the declarative contract without activating anything (new Markdown files need not be staged):

```sh
nix eval --json .#nixosConfigurations.abhaile.config --apply 'c:
  assert c.programs.steam.enable && c.programs.alvr.enable;
  assert !c.programs.steam.remotePlay.openFirewall && !c.programs.steam.dedicatedServer.openFirewall;
  assert builtins.all (p: builtins.elem p c.networking.firewall.allowedTCPPorts
    && builtins.elem p c.networking.firewall.allowedUDPPorts) [ 9943 9944 ];
  assert builtins.any (p: (p.pname or "") == "android-tools") c.home-manager.users.df.home.packages;
  assert c.services.llama-cpp.enable && c.systemd.services.llama-cpp.enable;
  assert c.systemd.services.llama-cpp.wantedBy == [] && c.systemd.services.llama-cpp.requiredBy == [];
  true'
```

A full build is `nix build --no-link .#nixosConfigurations.abhaile.config.system.build.toplevel`. Evaluation/build does
not prove headset, encoder, audio or transport functionality. No switch/deploy is implicit.

## Looking Glass development setup — deferred, not installed

[Looking Glass](https://looking-glass.io/) displays a **Windows VM on a Linux desktop** via shared memory. It is not a
Quest transport, not a replacement for ALVR, and does not by itself make Windows PC VR work on a Quest. This task
installs no client, Windows host/IDD driver, OBS plugin, KVMFR module or Windows VM.

Before a separate implementation:

1. Agree the Windows application/workflow and a GPU plan. Keep the RX 9070 available to Linux VR. Do **not** bind it to
   VFIO or enable IOMMU/passthrough/boot changes under this task. Determine whether another suitable GPU exists and
   which GPU would drive the Linux desktop versus Windows; do not assume the iGPU is a suitable Windows VR GPU.
2. Select a specific **development** build from [official downloads](https://looking-glass.io/downloads). Pin its exact
   commit/build and match the Linux client, Windows host/IDD and any plugin to that build's documentation, rather than
   mixing stable and development binaries. The previous research observed B7-829-cdba29f2; recheck when installing,
   not a requested pin here.
3. Read that build's [requirements](https://looking-glass.io/docs/B7-829-cdba29f2/requirements/). Plan Windows capture/
   virtual display, shared-memory sizing and permissions. Its IDD virtual display avoids a dummy plug; hardware GPU
   processing is strongly recommended. KVMFR is recommended and required for direct GPU imports, not permission to add
   a kernel module before the design is agreed.
4. Only then define the Nix client/kernel/VM changes and verify Linux desktop recovery, VM display, input/audio,
   access restrictions on shared memory and rollback. Treat Windows VR/Quest integration as a separate feasibility
   test, not a Looking Glass feature promise.

## Sources

Rechecked 2026-10-17 against upstream:

- [ALVR installation](https://github.com/alvr-org/ALVR/wiki/Installation-guide)
- [Linux troubleshooting](https://github.com/alvr-org/ALVR/wiki/Linux-Troubleshooting) (vrmonitor workaround, RADV,
  hybrid GPU and PipeWire guidance)
- [Native wired mode](https://github.com/alvr-org/ALVR/wiki/ALVR-wired-setup-\(ALVR-over-USB\))
- [ALVR 20.14.1 adb lookup](https://github.com/alvr-org/ALVR/blob/v20.14.1/alvr/adb/src/commands.rs) (`get_adb_path` prefers
  PATH over downloaded platform-tools)
- [Meta developer/device setup](https://developers.meta.com/horizon/documentation/native/android/mobile-device-setup/)
  (linked by ALVR; account/device steps may change)

Locked module/package sources are authoritative for installed configuration: nixpkgs `nixos/modules/programs/alvr.nix`,
`programs/steam.nix`, `services/misc/llama-cpp.nix`, `rename.nix` (removed adb option),
`pkgs/by-name/al/alvr/package.nix`; USB policy is systemd's `70-uaccess.rules`.
