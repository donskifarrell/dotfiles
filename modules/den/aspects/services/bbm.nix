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

      sops.templates."bbm.env" = {
        owner = "bbm";
        group = "bbm";
        mode = "0400";
        content = ''
          GOCARDLESS_SECRET_ID=${config.sops.placeholder."bbm/gocardless_secret_id"}
          GOCARDLESS_SECRET_KEY=${config.sops.placeholder."bbm/gocardless_secret_key"}
          JWT_SECRET_KEY=${config.sops.placeholder."bbm/jwt_secret_key"}
          TELEGRAM_BOT_TOKEN=${config.sops.placeholder."bbm/telegram_bot_token"}
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

        # Non-secret configuration only. An exported variable beats the env
        # file, which is what makes this split work: secrets in the 0400 file,
        # everything else visible in `systemctl cat bbm`.
        environment = {
          ENV = "production";
          ENV_FILE = envFile;
          APP_LOG_LEVEL = "info";

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
