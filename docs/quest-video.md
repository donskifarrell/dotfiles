# Quest video network share

Active: **read-only WebDAV**, provided by miniserve on abhaile. Browser player removed.

In the headset's native video player, add a network location:

- Protocol: **WebDAV** (not WebDAVS).
- URL: **http://192.168.178.28:18083/**
- Host: `192.168.178.28`, port: `18083`, path: `/` if entered separately.
- Authentication: anonymous / none; leave username and password empty.
- Folder served: `/home/df/Videos/VR`. Select stereo/projection in the native player.

Same home LAN only. No encryption or login: anyone on the allowed LAN can read this folder while running.
No uploads, deletion, hidden files, symlink following or transcoding. No router forwards or internet exposure.
Old `/videos/` and `/player.html` URLs are obsolete; files are directly below the share root.

```sh
sudo systemctl start quest-video
sudo systemctl stop quest-video
```

Manual-start only; not enabled at boot. Configuration: `modules/den/aspects/services/quest-video.nix`.
LAN address/interface/subnet are pinned; update and rebuild if they change. Never widen the share to HOME.

Verified after activation: WebDAV listing (`207`), video byte-range streaming (`206`), service active and media
mount read-only. Native headset-player compatibility/projection still needs checking.
