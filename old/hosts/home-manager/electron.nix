{config, ...}: {
  home = {
    file."electron25-flags.conf" = {
      source = "${config.home.homeDirectory}/.dotfiles/hosts/config/electron25-flags.conf";
      target = "${config.home.homeDirectory}/.config/electron25-flags.conf";
    };
  };
}
