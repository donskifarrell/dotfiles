# Direct VR video streaming to Quest 3S

- Owner: parent; status: complete as prepared configuration; checks/build/independent review passed. No activation authorized.
- User decisions: serve only `~/Videos/VR` (may create dedicated folder, no moving media), home LAN without login,
  manual-start only, prepare/build/review configuration without switch or starting LAN service.
- Goal: direct desktop-file streaming to Wolvic on Quest (180/360/stereo projection); no ALVR re-encoding, Jellyfin,
  paid player, router forwards, boot/GPU changes or automatic transcoding.
- Expected user journey: switch configuration when ready → put files in dedicated folder → start quest-video →
  open http://192.168.178.28:18083/ in Wolvic → fullscreen and select projection/stereo → stop service after viewing.
- Security: every device on allowed home LAN can read folder while running; read-only, no uploads/hidden files/symlink
  traversal, never share HOME. Bind current LAN address and narrow firewall opening to wlp8s0. Account for existing
  fully trusted tailscale/VM interfaces with service-level network restrictions. DHCP change fails closed.

## Paths / plan

- New `modules/den/aspects/services/quest-video.nix`; host include in `modules/den/hosts/abhaile.nix` only.
- miniserve 0.35.0 from locked nixpkgs; no existing NixOS miniserve module. Native --no-symlinks, default no upload/
  mutation/hidden files, video MIME/ranges. No custom frontend/player. Package built/substituted successfully at
  `/nix/store/8n3lzi6dj8dy8ql9ggh0ai2k5scz29cq-miniserve-0.35.0`; actual --help read (no --media-player flag).
- Systemd installed unit without wantedBy/socket activation; read-only bind of dedicated folder into sandbox; run
  as df to read private media, protect remaining HOME and filesystem. Tmpfiles creates absent Videos/VR on activation.
- Add one concise Python stdlib HTTP regression check in tests/quest-video.py (loopback only, temporary data inside repo).
- New docs/quest-video.md direct-stream setup, device install/projection instructions, codec/transcoding/network/
  security limits; docs/vr.md and AGENTS.md pointers; TODO.md acceptance/status update.
- New Nix file must not be git-added without permission. Evaluate a filtered source snapshot including tracked files
  plus this exact new module, not raw `path:` worktree (potential ignored secrets). Preserve existing staged changes.

## Acceptance / evidence

- Focused Nix eval: host-only enabled unit; manual start; LAN-specific bind/firewall; protected read-only share; tmpfiles
  correct owners; network restrictions; other hosts lack service. Full abhaile toplevel build if feasible.
- HTTP regression with packaged binary: listing/file/video MIME, byte-range 206 exact content, traversal/hidden/symlink
  blocked, mutations denied. No listening LAN service started; no outside-repo writes requested by implementation.
- Independent security/correctness review: `vr-video-review` on herdr pane `w1:p3`, tab `w1:t3`,
  anthropic/claude-sonnet-5 high (fresh admission allowed+known, 62% remaining observed), ready for prompt.
  Pi session `8f3ade8b-647d-4bd0-bc73-c16609b21353`; no duplicates. Reviewer edits nothing; no children/user questions.
- Sources read: https://github.com/svenstaro/miniserve (plus locked package/actual help),
  https://wolvic.com/dl/ (official Quest builds), Wolvic Media Playback wiki (projection modes), systemd resource-control
  docs (service network restrictions). Wolvic install is a manual headset step; no sideload authorized/performed.

## Verification observed

- `python3 tests/quest-video.py /nix/store/8n3lzi6dj8dy8ql9ggh0ai2k5scz29cq-miniserve-0.35.0/bin/miniserve` passed:
  listing, inline video/mp4, exact 206 range/body, blocked hidden/symlink/traversal, mutations denied. Only loopback
  listener and temporary fixture files inside repo; fixtures/process cleaned up. No actual video decoded.
- Filtered snapshot `/nix/store/ip5lv1v12adafxzy9nwpbx8qh1919pv6-quest-video-source` contains tracked current files plus
  exact new module/test, their parent dirs; ignores .git and all other untracked/ignored files. No git add performed.
- First eval mistakenly addressed flake default; corrected to `#nixosConfigurations --apply ...`. Focused assertions
  then passed: service enabled/manual/no reverse unit references; LAN-interface-only firewall; read-only bind and
  home/system protection; service network restrictions; no quest-video unit on eachtrach.
- Full `nix build --no-link --print-out-paths path:<filtered-source>#nixosConfigurations.abhaile.config.system.build.toplevel`
  succeeded: `/nix/store/znlvjl5ck4ix960jdjd67z8jl3bwjaws-nixos-system-abhaile-26.11.20260913.ef34387`.
- `systemd-analyze verify --man=no <built>/etc/systemd/system/quest-video.service` passed (unrelated cups.socket
  legacy /var/run warning). Current kernel has CONFIG_BPF_SYSCALL=y and CONFIG_CGROUP_BPF=y. No live BPF/service
  enforcement test, since activation is not authorized.
- `git diff --check`, `nixfmt --check` on new aspect + modified host passed. Existing nix eval warning:
  stdenv.isLinux deprecated. New docs added after build do not alter service closure.
- Independent review completed (anthropic/claude-sonnet-5, other provider): no correctness/security blockers; Ship as
  configuration. Reviewer checked actual unit/firewall script, live address, actual CLI, reran HTTP test, checked
  documented systemd mount behavior. Runtime cgroup/network/sandbox enforcement still requires post-activation check.
- Final repeat HTTP test passed; cmp verified actual aspect/host/test byte-identical to built filtered snapshot.
  Exact docs package-build command tested against snapshot. Final diff/nixfmt checks passed.
- Final live state: `systemctl show quest-video.service -p LoadState` = not-found; no :18083 listener; Videos/VR still
  absent (created by tmpfiles only on user activation). No staging, switch, folder creation or media movement performed.
- Own reviewer tab w1:t3 may now be closed after recording evidence; child finished. Do not reuse its session ID while
  a process is still open.

## Next / hazards

User handoff: review/stage new `modules/den/aspects/services/quest-video.nix` explicitly (normal git flake otherwise
cannot see it), then switch when ready; put chosen videos in newly created ~/Videos/VR; manual `sudo systemctl start
quest-video`; open http://192.168.178.28:18083/ in Wolvic; select projection and test; stop afterwards. New guide:
docs/quest-video.md. No switch, LAN serving, router changes, media moves/downloads or headset install performed.
DHCP address/interface/subnet pinned to observed home network. No full flake check, runtime service/filter test,
Quest decoding/projection/codec/real-video or sustained-throughput test. Existing evaluation/cups warnings unrelated.
