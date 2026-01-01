{
  modules,
  config,
  pkgs,
  ...
}:
{
  imports = with modules.nixosModules; [
    avahi
    bluetooth
    flatpak
    fonts
    home-mgr-module
    i18n
    keyboard
    nh
    nix-config
    opensnitch
    openssh
    options
    printing
    sound
    touchpad
    sops-secrets

    # DE
    # cosmic
    gnome
  ];

  time.timeZone = "Europe/Dublin";

  my = {
    mainUser.name = "df";
    flakeHostname = "abhaile";
  };

  # Needed on the NixOS system to be set as default user shell
  programs.fish.enable = true;

  users.users =
    let
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA6h5RafG9hYqgT3nviJO9P9eEUEAHJlIEqFWfoxFOP6";
    in
    {
      root.openssh.authorizedKeys.keys = [ key ];

      ${config.my.mainUser.name} = {
        isNormalUser = true;
        openssh.authorizedKeys.keys = [ key ];
        shell = pkgs.fish;
      };
    };

  home-manager.users.${config.my.mainUser.name} = {
    imports = with modules.homeModules; [
      atuin
      delta
      direnv
      distrobox
      fish
      ghostty
      git
      neovim
      opensnitch-ui
      packages
      ssh
      starship
      tailscale
      udiskie
      vscode
      xdg
      yazi
      zellij
      zoxide

      secrets
    ];

    programs = {
      bat.enable = true;
      btop.enable = true;
      element-desktop.enable = true;
      eza.enable = true;
      fd.enable = true;
      fzf.enable = true;
      jq.enable = true;
      obsidian.enable = true;
      onlyoffice.enable = true;
      ripgrep.enable = true;
      trippy.enable = true;

      nix-index = {
        enable = true;
        enableFishIntegration = true;
      };
    };

    home = {
      sessionVariables = {
        LANG = "en_GB.UTF-8";
        LC_CTYPE = "en_GB.UTF-8";
        LC_ALL = "en_GB.UTF-8";
        PAGER = "less -FirSwX";
        MANPAGER = "sh -c 'col -bx | ${pkgs.bat}/bin/bat -l man -p'";
        MANROFFOPT = "-c";
      };

      stateVersion = "25.11";
    };
  };

  environment.systemPackages = with pkgs; [
  ];

  system.stateVersion = "25.11";
}
