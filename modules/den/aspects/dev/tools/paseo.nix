# dev.tools.paseo — the Paseo daemon (getpaseo/paseo) inside a `scoite dev`
# guest: a self-hosted server that drives coding agents (claude-code, codex,
# opencode) and exposes them over a web/mobile UI. Its whole point here is that
# the agent it drives runs in the sandbox, not on abhaile.
#
# Package source: paseo's own flake, not nix-ai-tools — numtide packages only
# `paseo-desktop` (the Electron app, installed on abhaile via apps.ai-tools);
# the daemon lives in the upstream repo's nix/package.nix, with nix/module.nix
# alongside it.
#
# The overrideAttrs below carries https://github.com/getpaseo/paseo/pull/3250,
# still open as of 2026-08-24: the install phase traces the daemon's runtime
# closure statically and misses node-pty's `prebuilds/` directory, so every
# terminal pane fails to start in a Nix-built daemon (upstream issue #3249).
# **Drop this override once the PR merges** — check before each `nix flake
# update`.
{ inputs, ... }:
{
  flake-file.inputs.paseo = {
    url = "github:getpaseo/paseo";
    inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  den.aspects.dev.tools.paseo.nixos =
    { pkgs, ... }:
    {
      imports = [ inputs.paseo.nixosModules.paseo ];

      services.paseo = {
        enable = true;

        package = (inputs.paseo.packages.${pkgs.stdenv.hostPlatform.system}.paseo).overrideAttrs (old: {
          postInstall = (old.postInstall or "") + ''
            # PR 3250: node-pty's prebuilt binaries aren't reachable from
            # the traced module graph, so terminal panes die on spawn.
            cp -r packages/server/node_modules/node-pty/prebuilds \
              "$out/lib/paseo/packages/server/node_modules/node-pty/"
          '';
        });

        # Runs as the sandbox's own user, so the agents it spawns inherit
        # iosta's PATH (the module's inheritUserEnvironment defaults to true
        # for a non-`paseo` user) and its state lands in /home/iosta/.paseo —
        # the persistent home volume, so sessions survive stop/start.
        user = "iosta";
        group = "users";

        port = 6767;

        # The guest runs no firewall (see microvm-guest.nix): reachability is
        # decided entirely by which ports the host forwards, so binding wide
        # here exposes the daemon to the host's forward and nothing else.
        listenAddress = "0.0.0.0";

        # DNS-rebinding protection: the daemon rejects Host headers it doesn't
        # know. Loopback and bare IPs are always allowed; `.local` is what a
        # browser sends for the guest's mDNS name (TASKS.md S9).
        hostnames = [ ".local" ];

        # Voice off. Both features default to a `local` speech provider, and
        # the daemon then downloads its models (parakeet-tdt-0.6b + kokoro,
        # hundreds of MB) into $PASEO_HOME on first start — i.e. into every
        # sandbox's persistent home volume, per instance, for a feature a
        # headless guest cannot use. Voice belongs to paseo-desktop on abhaile.
        settings.features = {
          dictation.enabled = false;
          voiceMode.enabled = false;
        };

        # No relay. `relay.enable = true` (upstream's default) dials
        # app.paseo.sh so the mobile app can reach the daemon from anywhere —
        # exactly the outbound channel a sandbox is supposed not to have. The
        # daemon still accepts direct connections from the host and, once
        # TASKS.md S11 lands, from the LAN.
        relay.enable = false;
      };

      # /home/iosta is a separate virtio volume and its ownership is fixed at
      # boot by scoite-home-perms; without both of those, paseo's preStart
      # would write config.json into a root-owned mountpoint.
      systemd.services.paseo = {
        after = [ "scoite-home-perms.service" ];
        requires = [ "scoite-home-perms.service" ];
        unitConfig.RequiresMountsFor = "/home/iosta";
      };
    };
}
