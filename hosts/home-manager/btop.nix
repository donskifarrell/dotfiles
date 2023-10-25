{
  config,
  lib,
  pkgs,
  ...
}: {
  home = {
    file."btop-catppuccin-macchiato" = {
      source = "${config.home.homeDirectory}/.dotfiles/hosts/config/theme/btop-catppuccin-macchiato.theme";
      target = "${config.home.homeDirectory}/.config/btop/themes/btop-catppuccin-macchiato.theme";
    };
  };

  programs.btop = {
    enable = true;

    settings = {
      color_theme = "btop-catppuccin-macchiato.theme";
      theme_background = false;
    };
  };
}
