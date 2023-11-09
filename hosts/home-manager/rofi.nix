{config, ...}: {
  home = {
    file."rofi" = {
      source = "${config.home.homeDirectory}/.dotfiles/hosts/config/rofi";
      target = "${config.home.homeDirectory}/.config/rofi";
    };
  };
}
