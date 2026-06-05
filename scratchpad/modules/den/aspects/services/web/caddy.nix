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
        package = pkgs.caddy;

        virtualHosts."short.tail8f3a60.ts.net".extraConfig = ''
          tls internal

          encode zstd gzip

          # Redirect /syncthing -> /syncthing/
          redir /syncthing /syncthing/ 308

          # Syncthing wants to live at /, so rewrite with handle_path
          handle_path /syncthing* {
            reverse_proxy 127.0.0.1:8384 {
              header_up Host localhost
            }
          }

          respond "OK" 200
        '';
      };

      # Only reachable over Tailscale, never the public internet.
      networking.firewall.interfaces.${tailscaleIf}.allowedTCPPorts = [
        80
        443
      ];
    };
}
