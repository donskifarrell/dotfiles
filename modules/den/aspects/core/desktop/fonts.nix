# core/fonts — system font packages. Filed under `core` (a foundational
# look-and-feel concern) rather than `desktop`, so any host can include it
# directly. Ported from modules/system/fonts.nix.
{
  den.aspects.core.desktop.fonts.nixos =
    { pkgs, ... }:
    {
      fonts = {
        enableDefaultPackages = true;
        packages = with pkgs; [
          source-code-pro
          font-awesome
          nerd-fonts.fira-code
        ];
      };
    };
}
