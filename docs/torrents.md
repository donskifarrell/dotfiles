# Transmission on abhaile

Transmission **GTK desktop app**, installed through df's workstation media bundle
(`modules/den/aspects/apps/bundles/media.nix`, `pkgs.transmission_4-gtk`). Launch **Transmission** from GNOME or run
`transmission-gtk`. No NixOS daemon, boot/login autostart or web interface is configured.

## Download location

The app's normal mutable settings live at `~/.config/transmission/settings.json` (mode 0600). They are **not** an
immutable Home Manager symlink: Transmission must be able to save its other preferences. This installation configured:

```json
{
  "download-dir": "/home/df/Downloads/transmission",
  "incomplete-dir": "/home/df/Downloads/transmission/.incomplete",
  "incomplete-dir-enabled": false,
  "port-forwarding-enabled": false,
  "rpc-enabled": false
}
```

Both completed and in-progress downloads go under **`~/Downloads/transmission`**, created private to df. The separate
incomplete folder is disabled; if enabled later, its configured path is still inside that same download root.
These are defaults, not OS-level confinement: manually changing the destination in the add-torrent dialog overrides
it. Existing torrents keep their own saved destination; none existed at installation.

On a fresh home directory, create this folder and configure the app's **Preferences → Downloading** accordingly;
Nix installs the program, while these mutable per-user preferences persist in the home directory. Close Transmission
before editing JSON manually, or its in-memory preferences can overwrite the edit. Preserve unrelated settings.
Transmission 4.1.3 accepts these kebab-case keys; version 4 still writes this format by default, while v5 transitions
to snake_case. Official [configuration docs](https://github.com/transmission/transmission/blob/4.1.3/docs/Editing-Configuration-Files.md).

## Legal test and repeating it

Use only content you have permission to download/share. WebTorrent's
[public-domain/Creative Commons test list](https://webtorrent.io/free-torrents) includes **Sintel**.

- Official metadata: https://webtorrent.io/torrents/sintel.torrent
- Infohash v1: `08ada5a7a6183aae1e09d831df6748d566095a10`.
- **The whole torrent is about 129 MB.** For a tiny test, add it **paused**, deselect every file, then select only
  **`Sintel.en.srt`** (about 1.5 KB) before starting. Set destination to `~/Downloads/transmission`.
- BitTorrent transfers whole pieces, so this file can require downloading a 128-KiB boundary piece and leave a
  small partial-data file for neighbouring unwanted files. No need to select/download the movie.
- Wait for the selected file to finish and then pause the torrent/quit the test client so it does not keep seeding.
  Transmission verifies received pieces against the hashes in the torrent metadata.

The installation check uses the same packaged Transmission engine in a **temporary foreground process**, with only
Unix-socket RPC control (no TCP/web control listener), and a copy of the GTK download defaults. It adds the torrent
paused, selects the one subtitle, then stops and cleans up the test process. Runtime evidence is recorded in
`.pi/workflow/tasks/004-transmission.md`. On 2026-10-17 the peer-only test (HTTP webseeds removed, same infohash)
reached completion for the selected file. The resulting `~/Downloads/transmission/Sintel/Sintel.en.srt` is 1,514 bytes
and matches the official subtitle byte-for-byte (SHA-256
`4ed7e1f1bc5ff69fe33606960e4c048ba6766237bf33b132fef76e1a92cb64b2`). No full movie downloaded. The temporary engine
was stopped; no daemon or RPC listener remains. Test engine state was temporary; the legal file/official torrent
metadata stay under the requested download root. An additional forced torrent recheck did not meet the test's strict
stopped/complete assertion and is **not** counted as passed; the independent file-content verification did pass.

## Network / privacy

No host firewall opening, UPnP/NAT-PMP router port mapping, router forwarding or VPN/routing change is added. Outgoing
peer connections usually suffice to download from a healthy swarm; inbound connectability/seeding performance may be
limited. The GTK package includes CLI tools, but no background service is installed or enabled.

BitTorrent is **not anonymous**: peers/trackers see the public IP used by the current route (including a selected
Tailscale exit node). Encryption preferences are not a VPN or a kill switch. This task does not promise anonymity.

For Quest video playback, this folder is **not automatically shared**. Only files you explicitly copy into
`~/Videos/VR` are offered by [quest-video](quest-video.md) while that separate manual service runs. Never add a symlink
or broaden the share to all Downloads just to expose a torrent folder.
