# VR video files: abhaile → Quest 3S

**Prepared, not activated.** This setup serves `~/Videos/VR` read-only over the home LAN. Open the files in **Wolvic**
on the headset and select their VR projection/stereo mode. SteamVR and ALVR are not needed for this path.

- Server: open-source miniserve, pinned by nixpkgs; `services.quest-video` aspect on **abhaile only**.
- URL: **http://192.168.178.28:18083/** (IPv4 Wi-Fi address/interface `wlp8s0`).
- Manual-start only. No password, uploads, deletion, symlink following, hidden files or transcoding.
- **Everyone on the allowed LAN can browse/download this folder while running.** HTTP is unencrypted. Put only files
  you intend to share here; never point it at HOME. No router forwards, Tailscale Serve or internet exposure configured.

## Apply when ready

New Nix files must be tracked for a normal git-flake rebuild. The agent has not staged anything. After reviewing the
changes, include `modules/den/aspects/services/quest-video.nix` in Git's index yourself, then:

```sh
sudo nixos-rebuild switch --flake .#abhaile
```

Activation creates `/home/df/Videos` and `/home/df/Videos/VR`, owned by df:users, mode 0700. The service remains stopped;
there is no boot-target or socket activation. Copy/move the videos you choose into `~/Videos/VR` yourself. Do not use
symlinks: they are deliberately blocked, even within the share. Files must be readable by df.

```sh
sudo systemctl start quest-video
systemctl status quest-video --no-pager
curl -I http://192.168.178.28:18083/
```

After viewing:

```sh
sudo systemctl stop quest-video
```

There is no need to start inference, ALVR or SteamVR. If those are running only for video, close them to save GPU work.
The server sends original file bytes; the Quest decodes the video locally, with no second video-encoding pass.

## Play on the Quest

1. Install **Wolvic**, the free/open-source VR browser, via the project's official
   [download/store links](https://wolvic.com/dl/). A Quest APK is available there if store installation is unavailable;
   use only an official Quest build. This task does not install/sideload anything on the headset. Sideloaded builds
   need manual updates.
2. Connect the Quest to the same home LAN as abhaile. Guest Wi-Fi/client isolation can prevent access. Desktop Wi-Fi
   works, but Ethernet to the router is preferable for high-bitrate files. The server currently allows only `wlp8s0`
   and loopback: update the aspect before switching to an Ethernet interface.
3. In Wolvic, visit **http://192.168.178.28:18083/** and open a video. Bookmark this address.
4. Enter fullscreen and select the **projection/VR-goggles** control. Match the actual file format:

   | File | Projection |
   | ---- | ---------- |
   | Ordinary flat video | 2D |
   | Flat stereoscopic movie | 3D side-by-side (if encoded SBS) |
   | 180° stereo, left/right images | 180° stereo left-to-right |
   | 180° stereo, top/bottom images | 180° stereo top-to-bottom |
   | 360° mono / stereo | Matching 360° / 360° stereo mode |

   Wrong projection looks stretched, doubled or flat. A name such as SBS/LR/OU/TB is a hint, not proof of the file's
   layout. Wolvic's documented modes do not guarantee support for every cubemap/fisheye layout.
5. Check both eyes, head tracking, audio and seeking. Proper projection is provided by the headset player, not by
   the file server. Native fullscreen playback does not require turning this HTTP server into a WebXR application.

### Codec / performance limits

Start with a browser-compatible **H.264, 8-bit, AAC-audio MP4** VR file. HEVC/AV1, 10-bit/HDR, MKV, unusual audio,
subtitles, very high resolution/bitrate and sustained playback need testing with your chosen Wolvic build and files.
The server does **not** convert unsupported formats; renaming an extension will not fix the codec. If playback fails,
inspect the file's codecs before changing firewall/ALVR settings. No media was downloaded or copied by this task.

For a player that downloads instead of displaying an MKV, first test MP4. HTTP byte ranges are supported and tested,
so seeking does not require downloading the whole file when the player supports streaming that format.

## Network and service boundaries

The aspect lives in `modules/den/aspects/services/quest-video.nix`. It binds **192.168.178.28**, not `0.0.0.0`, and opens
TCP 18083 only on `wlp8s0`. Because the host already trusts its tailnet/VM interfaces, the service additionally uses
systemd network-interface and peer-IP allowlists for loopback/home LAN. These require the host's cgroup/BPF support;
after activation, inspect its journal for any unsupported-filter warnings and test reachability from the Quest.

The current home subnet is `192.168.178.0/24`. If DHCP changes abhaile's address, startup fails rather than falling back
to all interfaces. Update the `address` in the aspect and rebuild (and update the subnet/interface restrictions if
moving networks). A DHCP reservation on your router can avoid address changes; none was configured here.

The unit runs as df to read private media. It sees the selected folder as a **read-only bind mount** at
`/srv/quest-video`, hides the rest of HOME and makes the filesystem read-only. HTTP symlinks/traversal are blocked by
the server; this is not a general sandbox for arbitrary untrusted programs.

```sh
journalctl -u quest-video -n 50 --no-pager
ip -brief -4 address show wlp8s0
```

Do not disable the firewall to diagnose a playback issue. If the page loads but a movie does not, focus on format,
projection or Wi-Fi throughput. If the page does not load, check service status, desktop address and AP isolation.

## Verification and remaining acceptance

The small HTTP regression check uses the packaged binary on **loopback only**, temporary fixture files and no live
systemd service. From the repo after the new module is tracked:

```sh
server=$(nix build --no-link --print-out-paths .#nixosConfigurations.abhaile.pkgs.miniserve)
python3 tests/quest-video.py "$server/bin/miniserve"
```

It checks directory browsing, inline MP4 MIME, exact `206` range contents, blocked hidden/symlink/traversal requests and
rejected mutations. This is not a real video-decode test or proof of the systemd sandbox's runtime behavior.

- [ ] User activates configuration; service is initially inactive and not boot-enabled.
- [ ] Manual start works; no sandbox/network-filter warnings; folder stays read-only over HTTP.
- [ ] Quest opens listing and plays a real VR file with correct stereo/projection, sound, tracking and seeking.
- [ ] Devices outside the allowed network cannot connect; stop closes port 18083; reboot does not start sharing.

Sources: [miniserve](https://github.com/svenstaro/miniserve), [Wolvic](https://wolvic.org/),
[Wolvic projection modes](https://github.com/Igalia/wolvic/wiki/Media-Playback),
[systemd network controls](https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html).
