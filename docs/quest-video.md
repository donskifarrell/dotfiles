# Quest video network share

Active: **read-only WebDAV**, provided by miniserve on abhaile. Browser player removed.

In the headset's native video player, add a network location:

- Protocol: **WebDAV** (not WebDAVS).
- URL: **http://192.168.178.28:18083/**
- Host: `192.168.178.28`, port: `18083`, path: `/` if entered separately.
- Authentication: anonymous / none; leave username and password empty.
- Folder served: `/home/df/Videos/VR`. Select stereo/projection in the native player.

## DeoVR (SMB)

The same folder is also served read-only over **SMB with a password**, because DeoVR cannot use WebDAV. DLNA was
rejected because it has no authentication and announces itself to the whole LAN. SMB is not announced either: no
NetBIOS/nmbd, no wsdd, so it does not appear in network browsing.

One-time setup on abhaile (this is a separate Samba password, not df's login password; it is stored in
`/var/lib/samba`): `sudo smbpasswd -a df`. Change it with `sudo smbpasswd df`.

In DeoVR, add an SMB/Samba server: host `192.168.178.28`, share `quest` (path `\\192.168.178.28\quest`), user `df`, and
that password. Port 445. Only `192.168.178.0/24` on `wlp8s0` can connect. Traffic is not encrypted; the password
exchange is NTLMv2.

## Limits

Same home LAN only. WebDAV has no encryption or login: anyone on the allowed LAN can read this folder while running.
No uploads, deletion, hidden files, symlink following or transcoding. No router forwards or internet exposure.
Old `/videos/` and `/player.html` URLs are obsolete; files are directly below the share root.

```sh
sudo systemctl start quest-video
sudo systemctl stop quest-video
```

One command starts or stops both WebDAV and SMB (`samba-smbd` is `PartOf` `quest-video`). Manual-start only; not enabled
at boot. Configuration: `modules/den/aspects/services/quest-video.nix`.
LAN address/interface/subnet are pinned; update and rebuild if they change. Never widen the share to HOME.

Verified after activation: WebDAV listing (`207`), video byte-range streaming (`206`), service active and media
mount read-only. Native headset-player compatibility/projection still needs checking.
