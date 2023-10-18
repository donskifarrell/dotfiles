{...}: {
  fonts.fonts = with pkgs; [
    dejavu_fonts
    jetbrains-mono
    font-awesome
    noto-fonts
    noto-fonts-emoji

    (nerdfonts.override {fonts = ["JetBrainsMono"];})
  ];
}
