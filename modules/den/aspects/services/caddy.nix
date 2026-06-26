# Ported from modules/system/caddy.nix. Reverse proxy for short's services,
# reachable only over Tailscale. The legacy `my.caddy.enable` gate is dropped —
# in Den, including this aspect activates it. The tailnet hostname below is
# short-specific; move it to host data if this aspect is reused elsewhere.
{
  den.aspects.services.web.caddy.nixos =
    { pkgs, ... }:
    let
      tailscaleIf = "tailscale0";
    in
    {
      services.caddy = {
        enable = true;

        # If you want extra plugins, swap package here.
        package = pkgs.caddy;

        virtualHosts."short.tail8f3a60.ts.net" = {
          # For a non-public .lan name, use Caddy's local CA.
          # You'll need to trust the generated root cert on your desktop (see below).
          extraConfig = ''
            tls internal

            # Optional hardening
            encode zstd gzip

            # Redirect /syncthing -> /syncthing/
            redir /syncthing /syncthing/ 308

            # Syncthing wants to live at /, so rewrite with handle_path
            handle_path /syncthing* {
              reverse_proxy 127.0.0.1:8384 {
                header_up Host localhost
              }
            }

            # (optional) default
            respond "OK" 200
          '';
        };

        # You can add more services like:
        # virtualHosts."grafana.short.lan".extraConfig = ''
        #   tls internal
        #   reverse_proxy 127.0.0.1:3000
        # '';
      };

      # Only allow access over Tailscale, not public internet
      networking.firewall.interfaces.${tailscaleIf}.allowedTCPPorts = [
        80
        443
      ];

      # (Optional) Ensure Syncthing GUI is not exposed publicly.
      # In NixOS Syncthing module you can usually keep it bound to localhost.
      # services.syncthing.guiAddress = "127.0.0.1:8384";
    };
}
