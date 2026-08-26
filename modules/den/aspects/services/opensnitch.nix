# opensnitch — the Linux application firewall (the Little Snitch analogue):
# a daemon that intercepts outbound connections and a tray UI that prompts.
#
# Both halves have their own idea of "what happens when nobody answers", and
# they are configured in different places:
#
#   daemon (services.opensnitch.settings)   what happens with no UI attached,
#                                           or when the UI never answers.
#   UI (~/.config/opensnitch/settings.conf) the popup's countdown, and which
#                                           action/duration it pre-selects.
#
# df's call (2026-08-26): a prompt nobody answers should **allow, forever** —
# not deny, and not the 12h the UI ships as its default duration. The prompt
# is a notification-with-veto here, not a gate.
{
  den.aspects.services.opensnitch = {
    nixos = _: {
      services.opensnitch = {
        enable = true;
        settings = {
          # What the daemon itself decides when it has to decide alone.
          DefaultAction = "allow";
          # Upstream ships "once", so an unattended allow evaporated
          # immediately and the same connection re-prompted forever.
          DefaultDuration = "always";
        };
      };
    };

    homeManager =
      { lib, pkgs, ... }:
      {
        services.opensnitch-ui.enable = true;

        # The UI keeps its settings in a Qt ini that it rewrites whenever any
        # preference changes, so it cannot be a home-manager symlink (the UI
        # would fail to save). Same pattern as dev/vscode.nix's settings.json:
        # a mutable file, with just the keys we care about asserted on every
        # activation. Everything else in that file stays the UI's business.
        #
        # Keys (opensnitch-ui 1.8.0, opensnitch/config.py + prompt.ui):
        #   default_action    0 = deny, 1 = allow
        #   default_duration  index into the popup's combo:
        #                     0 once · 1 30s · 2 5m · 3 15m · 4 30m · 5 1h
        #                     6 12h · 7 until reboot · 8 forever
        #                     (upstream's DEFAULT_DURATION_IDX = 6 is 12h; its
        #                     "# until restart" comment is off by one.)
        #   default_timeout   seconds the popup counts down before applying
        #                     default_action.
        home.activation.opensnitchUiDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          conf="$HOME/.config/opensnitch/settings.conf"
          if [ -f "$conf" ]; then
            run ${pkgs.gnused}/bin/sed -i \
              -e 's/^default_action=.*/default_action=1/' \
              -e 's/^default_duration=.*/default_duration=8/' \
              "$conf"
          fi
        '';
      };
  };
}
