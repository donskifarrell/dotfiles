{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    dejavu_fonts
    font-awesome
    jetbrains-mono
    nerd-fonts.jetbrains-mono
  ];
}
