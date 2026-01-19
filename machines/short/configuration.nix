{
  modules,
  config,
  pkgs,
  ...
}:
{
  imports = with modules.nixosModules; [
    avahi
    caddy
    home-mgr-module
    keyboard
    nix-config
    openssh
    options
    i18n

    testbed
  ];

  testbed.enable = true;

  time.timeZone = "Europe/Dublin";

  my = {
    mainUser.name = "mise";
    flakeHostname = "short";
    caddy.enable = true;
  };

  # TODO: really should pull this into a dedicated file
  systemd.tmpfiles.rules = [
    "d /home/${config.my.mainUser.name}/.config/syncthing 0700 ${config.my.mainUser.name} syncthing -"
    "d /home/${config.my.mainUser.name}/.local/state/syncthing 0700 ${config.my.mainUser.name} syncthing -"
    "d /home/${config.my.mainUser.name}/sync 2775 ${config.my.mainUser.name} syncthing -"
  ];

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
      zoxide
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

    my.packages = {
      # Tools
      curl.enable = true;
      dig.enable = true;
      inetutils.enable = true;
      lsof.enable = true;
      p7zip.enable = true;
      unrar.enable = true;
      unzip.enable = true;
      wget.enable = true;
    };

    home = {
      sessionVariables = {
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
