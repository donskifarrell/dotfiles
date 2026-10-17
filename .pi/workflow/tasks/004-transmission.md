# Transmission on abhaile

- Owner: parent; status: complete for installation + requested small legal download; functional/content checks passed. Extra forced-recheck state assertion did not pass (not counted). User authorized GTK app + activation + test.
- Scope: package on host, mutable GTK preferences under ~/.config/transmission/settings.json, all normal/default
  completed/in-progress downloads under ~/Downloads/transmission. No background service/autostart/network RPC UI,
  router forwards, firewall openings or VPN/routing changes. No staging/commits.
- Initial state: no Transmission executable/config/download directory or running client. Current repo config evaluates
  to running system `/nix/store/7lqjv7ndk03r954wbbn22b72gwqprgyd-nixos-system-abhaile-26.11.20260913.ef34387`.
  Existing Quest changes staged by user; preserve index. New quest-video module is now tracked and current build works.
- Approach: add locked `pkgs.transmission_4-gtk` (4.1.3, includes CLI utilities) to existing workstation media bundle;
  no new imported file/staging dependency. Set normal mutable app preferences once, not an immutable settings symlink
  or extra activation/wrapper/parser. Record mutable settings and reproduction steps in docs/torrents.md + AGENTS.md.
- Files: modules/den/aspects/apps/bundles/media.nix; docs/torrents.md; AGENTS.md; TODO.md; this checkpoint.
- Outside-repo writes authorized by installation choice: create ~/Downloads/transmission and ~/.config/transmission,
  new settings file (0600), legal torrent metadata and downloaded sample under requested download root only. Never
  overwrite existing settings if one appears or edit while GTK/CLI/daemon is running; initial check found none.

## Test plan / sources

- Full host build, focused package/no-daemon/no-extra-firewall assertions, then authorized system switch and confirm
  installed executable/default settings. Existing nixpkgs deprecation warning is unrelated.
- Legal small sample: English subtitle (about 1.5 KB) from official WebTorrent Sintel torrent. Metadata lists full
  movie too; add paused and select only the subtitle before starting, never download full movie accidentally.
  Sources https://webtorrent.io/free-torrents (public-domain/CC test list),
  https://webtorrent.io/torrents/sintel.torrent (129.3 MB full torrent, English subtitle file index 2 in CLI).
- Use a temporary foreground test engine with Unix-socket-only RPC control (no TCP/web interface, no installed service),
  default directory copied from GTK config, then stop/clean up. Leave downloaded legal file under requested root.
  Can strip the known top-level webseed metadata field for peer-only test without changing infohash; native
  transmission-show must validate metadata and same infohash before use. Report actual peer/transfer/hash evidence,
  never call a webseed-only download proof of peer connectivity. Stop test client on completion or timeout.
- Official 4.1.3 docs read: Editing-Configuration-Files.md / Configuration-Files.md: mutable JSON, app closed during
  edits; kebab-case remains v4 default, snake_case accepted since 4.1. No Home Manager transmission module found.
  Inspected locked package and actual GTK/CLI/daemon/remote help; remote supports --unix-socket.
- Packages substituted: GTK `/nix/store/gavayhf9q6vh8p4pc1cvb4x7ggjma9mb-transmission-4.1.3`, CLI
  `/nix/store/sf61zkvb23ajpy8x4gczqdkyn72yp5m7-transmission-4.1.3` (same 4.1.3 engine).

## Independent review

- Existing agents inspected; fresh alternative-provider admission anthropic/claude-sonnet-5: allowed+known, 55%
  remaining observed. Catalog includes model; actual start succeeded ready/idle. Reviewer `transmission-review`,
  pane w1:p4 (own sibling split, no focus), tab w1:t1, Pi session 01a14a67-3f87-7431-bc7e-459920332160.
- Independent alternative-provider review completed: Ship, no must/should/nice findings. Reviewer verified package
  placement/caller projection, closure contains GTK, private mutable settings match requested folder and no RPC/UPnP,
  docs consistent. No live download/switch or upstream metadata verification by reviewer. Parent owns live evidence.

## Evidence so far

- Added only GTK package to existing tracked media bundle. Created requested download folder + mutable settings
  (0600) with the five documented keys using exclusive-create; assert no Transmission process before writing.
- Full host build passed: `/nix/store/8k9zr8frnxq340iar0133vmk9v0i2j5w-nixos-system-abhaile-26.11.20260913.ef34387`.
  Focused eval asserts GTK in df packages and NixOS daemon disabled. Firewall unit byte-identical to current system;
  closure diff adds only Transmission 4.1.3, completions, libnatpmp, miniupnpc and updated HM generation.
- No live switch yet. docs/torrents.md documents mutable preferences, legal selective-download test and privacy limits;
  AGENTS.md + TODO.md linked. git diff --check and nixfmt --check on media.nix passed.
- Authorized `sudo -n nixos-rebuild switch --flake .#abhaile` succeeded. Active system:
  `/nix/store/lm2sqvh4cxayv77cq5dn9iqxsks6f9js-nixos-system-abhaile-26.11.20260913.ef34387`.
  `nix store diff-closures` versus built 8k9zr8f... has no changes. Actual per-user executable resolves to locked GTK
  package; `transmission-gtk --version` = 4.1.3. Prior 7lqjv7nd... remains known-good generation. Activation emitted
  unrelated existing gdm-greeter UID-change warnings; no fix attempted. Index preserved.
- Actual GUI process PID 1262084 is now running (likely user opened it after installation). Do not kill/rewrite its
  preferences. Read only selected settings; still exact requested paths, RPC and port forwarding disabled.
- First temporary test failed before adding any torrent: bare `/path/rpc.sock` was invalid; engine fell back to
  0.0.0.0:9091 for ~10s with default IP whitelist enabled. Parent terminated own engine, cleaned temporary directory,
  verified no :9091 listener remains and disclosed error to user. No persistent config affected or torrent added.
  Tagged source rpc-server.cc confirms required prefix `unix:`; retry uses `rpc-bind-address=unix:/absolute/path` and
  private socket mode0600. Copy only five approved preferences into test config, not unrelated GUI settings.
- Original official Sintel metadata saved at ~/Downloads/transmission/sintel-legal-test.torrent. Temporary metadata
  removed only the known top-level url-list field (bencoded URL length computed, not hand-written). Native
  transmission-show validated unchanged infohash and no WEBSEEDS before transfer; RPC webseeds list stayed empty.
- Socket retry worked (0600) but initial paused-status assertion ran during asynchronous initial verification (status2).
  Preflight inspected actual file names/wanted indices; all paused, zero bytes. Corrected test waits for status0 before
  start, selects only English subtitle at zero-based RPC/native-CLI index1 (not the previously assumed 1-based CLI2).
- Peer-only test reached percentDone=1 and selected bytesCompleted=1514 before the extra recheck. An additional
  stop+forced-verify step did not satisfy the strict status0/percentDone1 assertion within 10s; exact final state was
  not retained. Do NOT claim forced recheck passed. No production config/code changed to bypass this assertion.
- Independent verification fetched the official subtitle reference into memory AFTER torrent download and compared
  byte-for-byte: PASS, exactly 1514 bytes; SHA256 4ed7e1f1bc5ff69fe33606960e4c048ba6766237bf33b132fef76e1a92cb64b2.
  Path: /home/df/Downloads/transmission/Sintel/Sintel.en.srt. Full Sintel.mp4 does not exist. No upload/seeding/client
  was left by test; every temporary engine/socket/config/log directory was removed in finally. GUI remains user-owned.
- Final assert-based self-check passed: installed GTK4.1.3 (version prints to stderr; capture both streams), all five
  selected preferences correct, private0700 download root, legal file size/hash, no CLI/daemon process. No TCP9091
  listener; systemctl transmission.service LoadState=not-found. git diff --check and nixfmt media.nix passed.
- Remaining limits: no sustained/large torrent throughput, inbound connectivity/seeding, full flake check, or GUI
  interactions tested by parent. Forced recheck not counted; normal completed-file content verified separately.

## Next / hazards

Handoff: launch Transmission from GNOME or transmission-gtk; defaults already configured and system activated.
No rebuild needed. Legal sample/official .torrent remain in requested root; other test artifacts/processes cleaned.
Own reviewer pane w1:p4 can now be closed (evidence saved). Preserve staged Quest work; no stage/commit performed.
Public BitTorrent peers see routed public IP; no anonymity/VPN guarantee. Download folder is an app default, not OS
confinement: user can override per torrent. No arbitrary downloaded payload executed as code.
