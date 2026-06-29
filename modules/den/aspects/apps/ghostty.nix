# Ported from modules/home/ghostty.nix.
{
  den.aspects.apps.ghostty = {
    homeManager = {
      programs.ghostty = {
        enable = true;
        enableFishIntegration = true;
        installBatSyntax = true;
        systemd.enable = true;

        settings = {
          shell-integration-features = "ssh-terminfo";
          clipboard-read = "allow";
          clipboard-write = "allow";
          copy-on-select = "clipboard";
        };
      };
    };

    nixos =
      { pkgs, ... }:
      {
        # xterm-ghostty terminfo for root.
        environment.sessionVariables.TERMINFO_DIRS = "/run/current-system/sw/share/terminfo";

        environment.systemPackages = with pkgs; [
          ghostty
        ];
      };
  };
}
