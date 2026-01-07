{
  modules,
  config,
  pkgs,
  ...
}:
{
  imports = with modules.nixosModules; [
    avahi
    home-mgr-module
    keyboard
    nix-config
    openssh
    options
  ];

  time.timeZone = "Europe/Dublin";

  my = {
    mainUser.name = "mise";
    flakeHostname = "short";
  };

  # Needed on the NixOS system to be set as default user shell
  programs.fish.enable = true;

  users.users =
    let
      # TODO: switch to clan secrets
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
      difftastic
      direnv
      eza
      fish
      git
      neovim
      packages
      ssh
      xdg
      yazi
      zellij
      zoxide
    ];

    home.packages = with pkgs; [
      curl
      dig
      inetutils
      p7zip
      unrar
      unzip
      wget
    ];

    programs = {
      bat.enable = true;
      btop.enable = true;
      fd.enable = true;
      fzf.enable = true;
      jq.enable = true;
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
    eza
  ];

  system.stateVersion = "25.11";
}
