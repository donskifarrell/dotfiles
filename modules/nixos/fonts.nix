{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    dejavu_fonts
    jetbrains-mono
    font-awesome

    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
  ];
}
