# Ported from modules/system/fonts.nix.
{
  den.aspects.desktop.fonts.nixos =
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
