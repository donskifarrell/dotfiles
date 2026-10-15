# Collie — herdr on your phone, from a scoite sandbox

[Collie](https://colliepwa.dev) is a phone web app (PWA) that mirrors herdr panes: read agents, reply, dictate. Here it
runs **only inside a `dev` scoite guest you enable it in** — never on abhaile — so it can only reach what that sandbox
can reach.

```
phone (tailnet) ──https──▶ abhaile `tailscale serve` :<tport> ──▶ 127.x.y.1:<port> (qemu hostfwd)
                                                                   ──▶ guest 10.0.2.15:8787 collie ──▶ herdr socket
```

- The guest never joins the tailnet. abhaile's own `tailscale serve` is the front door, with its own tailnet cert
  (`https://abhaile.tail8f3a60.ts.net:<tport>`).
- Every `dev` guest has the `collie` binary plus a machine config (`~/.collie/config.toml`, from
  `modules/den/aspects/dev/tools/collie.nix`): bind `10.0.2.15` (SLIRP), no `tailscale serve` of its own. Nothing
  listens until you run `collie start` in that guest, and nothing reaches it from the phone until you run
  `scoite expose --tailnet` on the host.
- Access control: **pairing** (`collie pair`, per device) plus Host-header validation. `COLLIE_TRUSTED_USER` does not
  work here — Collie ignores it under `skip_serve`, so any device on the tailnet can reach the pair screen but cannot do
  anything without a code.
- Guests linger (`users.users.iosta.linger`), so collie's user unit keeps running after you detach from herdr.

## One-time setup

### Tailnet (admin console)

1. <https://login.tailscale.com/admin/dns> → MagicDNS on → **Enable HTTPS**. This publishes `*.tail8f3a60.ts.net` names
   to public Certificate Transparency logs. `scoite expose --tailnet` refuses to run until this is on.
2. df must be tailscale operator (already true, a runtime pref; on a fresh abhaile: `sudo tailscale set --operator=df`).

### abhaile

```bash
nixos-rebuild switch --flake ~/.dotfiles#abhaile   # new scoite CLI (--tailnet)
scoite stop bbm && scoite start bbm                # guest boots the new closure (collie + config + linger)
```

### Phone (Android)

Install the Tailscale app and sign in to the same tailnet.

## Enable Collie in a sandbox (e.g. `bbm`)

On **abhaile**:

```bash
scoite expose bbm --tailnet 8787        # → https://abhaile.tail8f3a60.ts.net:8787
# a second sandbox needs its own tailnet port:
# scoite expose other --tailnet --tailnet-port 8788 8787
```

In the **guest** (`scoite ssh bbm`, in a herdr pane). Use the tailnet port you just opened:

```bash
mkdir -p ~/.config/collie
echo COLLIE_PUBLIC_HOSTS=abhaile.tail8f3a60.ts.net:8787 >> ~/.config/collie/.env
echo COLLIE_PUBLIC_URL=https://abhaile.tail8f3a60.ts.net:8787 >> ~/.config/collie/.env
collie start        # writes + enables a systemd --user unit; picks herdr as the mux
collie pair         # prints a QR + 8-char code, valid 10 minutes
```

`COLLIE_PUBLIC_HOSTS` must match exactly, port included, or every request gets `403 host not allowed`.

On the **phone**:

1. Scan the `collie pair` QR code with the camera. It opens Collie with the code filled in. If it doesn't, open the URL
   in Chrome → Settings → System → Paired devices → enter the code.
2. Install: Collie Settings → **Install** card (or Chrome ⋮ → **Add to home screen** → Install).

## Voice input

Microphone input needs HTTPS, which the tailnet door already gives you. It needs no repo config. On the phone (paired
device): Collie **Settings → Voice → Set up speech on this phone**. That downloads the 17 MB
[Whistle](https://huggingface.co/Cactus-Compute/whistle) model into the guest (from Hugging Face), copies it to the
phone, and runs speech recognition **on the phone** (offline after that). Then tap the mic in the composer. Allow
Chrome's microphone prompt.

- Weak phone: Settings → Voice → **Change how speech works** → **On your host** runs Whistle in the guest instead. Or, in
  the guest, run `collie stt whistle --host`.
- Check from the guest: `collie stt status`, `collie stt test`.
- Whistle supports en/de/fr/es/it/nl/pl.

## Day to day

| Task                         | Command                                                                                                                                    |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Is it up? (guest)            | `collie status`, `collie doctor`, `collie logs`                                                                                            |
| Pair / revoke a device       | `collie pair [--expires 30d]`, `collie devices list`, `collie devices revoke <label>`                                                      |
| Close the phone door (host)  | `scoite unexpose bbm --tailnet 8787`                                                                                                       |
| Turn it off in a guest       | `collie uninstall` (also delete `~/.config/collie` and `~/.local/state/collie` for every trace)                                            |
| After `nix flake update collie` | stop/start the guest, then `collie restart` in it. The unit pins the old store path, and `collie update` declines on a Nix install. |

Tailnet doors live in tailscaled's own state: they survive reboots and guest stop/start (answering 502 while the guest
is down), and are removed by `scoite unexpose --tailnet` and `scoite rm`. `scoite list` shows them in the `TAILNET`
column (`guest:tailnet` pairs).

## Gotchas

- `collie start` in a guest prints `proxy http://…` from `COLLIE_PUBLIC_URL`. That URL is only informational. The real
  door is whatever `scoite expose --tailnet` opened.
- Bound to a non-loopback address, the bridge warns that "whatever fronts this port is now the only control". That's
  accepted: `10.0.2.15` is reachable only through qemu's hostfwd on abhaile's `127.x.y.1`. A guest on `scoitebr0` has
  no ordinary route to it, and every `/api` call still needs a pairing token.
- Don't `cp .env.example` over `~/.config/collie/.env` after a start. It drops the `COLLIE_MUX=herdr` that `start`
  wrote.
- `~/.collie/config.toml` is a home-manager symlink. For per-guest settings, use `~/.config/collie/.env` or
  `collie config init --instance` (`~/.config/collie/config.toml`).
- Web Push notifications are optional and not set up (`collie push-keys`, see `collie docs voice-and-push`).
