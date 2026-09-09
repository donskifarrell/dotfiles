# bbm hosted on eachtrach and reachable only over the tailnet. Full reference: docs/bbm.md.
#
# Two artifacts, both built from the app's own flake (~/dev/bbm exposes
# `packages.<system>.{bbm-server,bbm-web}`):
#   bbm-server  Go binary: the ConnectRPC API *and* the feed sync scheduler,
#               which is in-process — the "cron" workload is one long-running
#               unit, not a timer. Migrations are embedded and applied at boot.
#   bbm-web     static SPA assets, built with no baked-in API URL so the bundle
#               talks to whatever origin served it. caddy serves both from one
#               origin, which is why there is no CORS to configure.
#   bbm-charts  Node sidecar that draws the Telegram weekly report's chart,
#               loopback-only and never reached from outside this host.
#
# SOURCE PIN. The input is a local checkout, by deliberate choice (df,
# 2026-09-05): it deploys local commits with no push to GitHub first.
#
# Two consequences, both load-bearing:
#   - This flake does not evaluate on a machine without /home/df/dev/bbm.
#     `nix flake check`, `nix fmt` and `nixos-rebuild` all resolve every input,
#     so on such a machine they fail here, not just for bbm. Switching to the
#     remote is a one-line change: `git+ssh://git@github.com/donskifarrell/bbm`.
#   - `git+file:` (not `path:`) is REQUIRED. It exports the git tree, so it
#     honours .gitignore and deploys committed HEAD only. `path:` copies the
#     working directory verbatim — which would put bbm's plaintext .env, its
#     bank data under data/, and every node_modules into the world-readable nix
#     store. Do not "simplify" this to path:.
#
# A relative path cannot express any of this: nix resolves `path:../…` against
# the flake's STORE copy, so anything outside the flake directory is
# unreachable ("access to absolute path '/nix/store/…' is forbidden in pure
# evaluation mode"). `bbm-deploy` therefore overrides the input per-invocation
# instead, which is also what lets it deploy from a different checkout.
{ inputs, ... }:
{
  flake-file.inputs.bbm = {
    url = "git+file:///home/df/dev/bbm";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.services.bbm.nixos =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      packages = inputs.bbm.packages.${pkgs.stdenv.hostPlatform.system};

      # Loopback only: caddy is the sole ingress, and this port must never be
      # the thing the firewall is protecting.
      apiPort = 8080;

      # The sidecar's listener. Loopback only, like apiPort, and for a stronger
      # reason: it renders whatever SVG it is handed, so its only caller must
      # be bbm on this host. caddy never proxies it.
      chartPort = 8091;

      stateDir = "/var/lib/bbm";

      # Flip to true (and add `services.web.caddy.tailscale-tls` to the host)
      # to move to a real ts.net certificate. Shipping on HTTP because the
      # tailnet hop is WireGuard-encrypted and nothing is reachable off it; the
      # only cost measured in the app is that navigator.locks is unavailable on
      # an insecure origin, which web/apps/website/src/api.ts already handles
      # (token refresh falls back from cross-tab to per-tab single-flight).
      #
      # KNOWN RISK: GoCardless may refuse a non-https consent redirect URI. If
      # it does at first feed connect, this is the toggle to flip.
      useTLS = false;
      scheme = if useTLS then "https" else "http";

      # MagicDNS name. The tailnet domain is fixed for this account; the host
      # part is whatever machine includes this aspect.
      fqdn = "${config.networking.hostName}.tail8f3a60.ts.net";
      origin = "${scheme}://${fqdn}";

      envFile = config.sops.templates."bbm.env".path;
    in
    {
      # --- identity -------------------------------------------------------
      # Its own user and group: nothing else on the box may read the ledger or
      # the stored bank statements, and bbm may not read anything else.
      users.groups.bbm = { };
      users.users.bbm = {
        isSystemUser = true;
        group = "bbm";
        home = stateDir;
        description = "BBM service";
      };

      # --- secrets --------------------------------------------------------
      # eachtrach is deliberately not a recipient of shared.yaml (see
      # .sops.yaml), so these live in its own file. Assembled into ONE env file
      # by a sops template rather than passed as systemd `EnvironmentFile=`:
      # the app parses ENV_FILE itself, so the values never land in the unit's
      # environment block and therefore never in `systemctl show` or
      # /proc/<pid>/environ.
      sops.secrets =
        lib.genAttrs
          [
            "bbm/gocardless_secret_id"
            "bbm/gocardless_secret_key"
            "bbm/jwt_secret_key"
            "bbm/telegram_bot_token"
          ]
          (key: {
            sopsFile = inputs.self + "/secrets/eachtrach.yaml";
            inherit key;
          });

      # LAYER 1 (base). ENV_FILE names this file, and bbm resolves the overlay
      # as `dirname(ENV_FILE)/.env.$ENV` — which is why the overlay below is
      # rendered into the same /run/secrets/rendered directory rather than
      # anywhere more obvious.
      sops.templates."bbm.env" = {
        owner = "bbm";
        group = "bbm";
        mode = "0400";
        restartUnits = [ "bbm.service" ];
        content = ''
          GOCARDLESS_SECRET_ID=${config.sops.placeholder."bbm/gocardless_secret_id"}
          GOCARDLESS_SECRET_KEY=${config.sops.placeholder."bbm/gocardless_secret_key"}
          JWT_SECRET_KEY=${config.sops.placeholder."bbm/jwt_secret_key"}
          TELEGRAM_BOT_TOKEN=${config.sops.placeholder."bbm/telegram_bot_token"}
        '';
      };

      # LAYER 2 (overlay), selected by ENV=prod below. The counterpart of
      # ~/dev/bbm/.env.prod, rendered here instead of copied: that file is
      # .gitignore'd, so it is absent from the `git+file:` export this host
      # builds from, and copying it out of band would put a deploy's config
      # outside the closure (a from-scratch provision or a rollback would not
      # carry it) — and its bot token outside sops.
      #
      # Holds no secrets, hence 0444: `cat` it on the box the same way
      # `systemctl cat bbm` shows the rest. Secrets belong in layer 1.
      #
      # WHAT GOES HERE: prod-only *app* settings. NOT anything the unit
      # exports below — an exported variable beats both files, so a key in
      # both places is a silently dead line here. Notably WEB_BASE_URL is
      # host-derived (`origin`) and stays exported.
      #
      # CHART_RENDER_URL points at the bbm-charts unit below. Left unset it
      # would mean text-only Telegram reports (internal/telegram/bot.go).
      sops.templates.".env.prod" = {
        mode = "0444";
        restartUnits = [ "bbm.service" ];
        content = ''
          APP_LOG_LEVEL=debug
          CHART_RENDER_URL=http://127.0.0.1:${toString chartPort}
        '';
      };

      # --- the service ----------------------------------------------------
      systemd.services.bbm = {
        description = "BBM API and feed sync scheduler";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network-online.target"
          "sops-install-secrets.service"
        ];
        wants = [ "network-online.target" ];

        # Non-secret, host-derived configuration only. An exported variable
        # beats both env files, which is what makes the split work: secrets in
        # the 0400 base, prod app config in the 0444 overlay, and the values
        # this NixOS host decides visible in `systemctl cat bbm`.
        #
        # ENV must be exactly "prod": bbm builds the overlay filename from it
        # (`.env.$ENV`), so the old "production" looked for a `.env.production`
        # that has never existed and silently applied no overlay at all.
        environment = {
          ENV = "prod";
          ENV_FILE = envFile;

          SERVER_HOST = "127.0.0.1";
          SERVER_PORT = toString apiPort;

          SQLITE_PATH = "${stateDir}/sqlite.db";
          STORAGE_BASE_PATH = "${stateDir}/data";

          # One origin for both the GoCardless consent redirect and the CORS
          # allowlist (bbm's internal/weburl resolves it). Same-origin serving
          # means CORS never actually fires, but naming it explicitly keeps a
          # stray preflight from being answered with a wildcard.
          WEB_BASE_URL = origin;
          WEB_CORS_ORIGINS = origin;
        };

        serviceConfig = {
          Type = "exec";
          ExecStart = lib.getExe packages.bbm-server;
          User = "bbm";
          Group = "bbm";
          Restart = "on-failure";
          RestartSec = "5s";

          StateDirectory = "bbm";
          # 0750 + umask 0027: group-readable so the backup account can read
          # it, world-unreadable because this is a bank ledger.
          StateDirectoryMode = "0750";
          UMask = "0027";
          WorkingDirectory = stateDir;

          # Hardening. Egress is deliberately unrestricted: GoCardless and
          # Telegram do not publish stable address ranges, and a stale
          # allowlist fails as a silently-stalled sync rather than an error.
          CapabilityBoundingSet = [ "" ];
          DevicePolicy = "closed";
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateTmp = true;
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectProc = "invisible";
          ProtectSystem = "strict";
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = [
            "@system-service"
            "~@privileged"
            "~@resources"
          ];
        };
      };

      # --- chart sidecar --------------------------------------------------
      # Draws the weekly report's chart: POST /weekly {points,currency} -> PNG.
      # Separate from bbm.service because it is a separate runtime (Node, and
      # a jsdom + resvg render) with a completely different risk profile, and
      # because bbm treats it as optional — internal/telegram/reports.go calls
      # the chart "a bonus", logs a failure and sends the report as text. So
      # this unit being down, or absent, costs a picture and nothing else.
      #
      # DynamicUser: it holds no state and reads nothing on disk outside its
      # own store path. Nothing to own, so no account to keep.
      systemd.services.bbm-charts = {
        description = "BBM chart renderer (Telegram weekly report)";
        wantedBy = [ "multi-user.target" ];

        environment = {
          CHART_RENDER_HOST = "127.0.0.1";
          CHART_RENDER_PORT = toString chartPort;
        };

        serviceConfig = {
          Type = "exec";
          ExecStart = lib.getExe packages.bbm-charts;
          DynamicUser = true;
          Restart = "on-failure";
          RestartSec = "5s";

          # Same hardening as bbm, with two deliberate differences.
          #
          # NO MemoryDenyWriteExecute: this is V8, and a JIT needs to map pages
          # writable and then executable. Setting it kills node at startup.
          #
          # IPAddressDeny, which bbm cannot have (it calls GoCardless and
          # Telegram): the renderer takes JSON from bbm over loopback and
          # answers with a PNG. It has no reason to reach the network, and an
          # SVG rasteriser handed hostile input is exactly the component you
          # want unable to.
          IPAddressDeny = "any";
          IPAddressAllow = "localhost";

          CapabilityBoundingSet = [ "" ];
          DevicePolicy = "closed";
          LockPersonality = true;
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateTmp = true;
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectProc = "invisible";
          ProtectSystem = "strict";
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = [
            "@system-service"
            "~@privileged"
            "~@resources"
          ];
        };
      };

      # --- ingress --------------------------------------------------------
      # Requires services.web.caddy on the same host. The site address carries
      # an explicit scheme: with `http://`, caddy serves plain HTTP and does
      # not attempt certificate issuance.
      services.caddy.virtualHosts.${origin}.extraConfig = ''
        encode zstd gzip

        # ConnectRPC procedure paths are /<proto package>.<Service>/<Method>,
        # and every bbm service's proto package starts with `bbm.` — so one
        # matcher covers the whole API surface and everything else is the SPA.
        handle /bbm.* {
          reverse_proxy 127.0.0.1:${toString apiPort}
        }

        # SPA fallback: real files win, anything else renders the app shell so
        # client-side routes survive a reload or a shared link.
        handle {
          root * ${packages.bbm-web}
          try_files {path} /index.html
          file_server
        }
      '';
    };
}
