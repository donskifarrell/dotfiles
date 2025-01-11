{pkgs, ...}: {
  gtk = let
    gtkExtra = {
      gtk-application-prefer-dark-theme = 1;
    };
  in {
    enable = true;
    cursorTheme = {
      name = "capitaine-cursors";
      size = 24;
    };
    iconTheme = {
      name = "Adwaita";
    };
    font = {
      name = "Cantarell 11";
    };
    theme = {
      name = "Catppuccin-Macchiato";
      package = pkgs.catppuccin-gtk.override {
        # accents = ["pink"];
        # size = "compact";
        # tweaks = ["rimless" "black"];
        variant = "macchiato";
      };
    };
    gtk3.extraConfig = gtkExtra;
    gtk4.extraConfig = gtkExtra;
  };
}
