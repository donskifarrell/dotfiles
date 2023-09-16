{
  config,
  pkgs,
  lib,
  ...
}: let
  user = "df";
  xdg_configHome = "/home/${user}/.config";
  # shared-programs = import ../shared/home-manager.nix {inherit config pkgs lib;};
  # shared-files = import ../shared/files.nix {inherit config pkgs;};
in {
  home = {
    enableNixpkgsReleaseCheck = false;
    username = "${user}";
    homeDirectory = "/home/${user}";
    packages = pkgs.callPackage ./packages.nix {};
    # file = shared-files // import ./files.nix {inherit user;};
    stateVersion = "23.05";
    sessionVariables = {
      LANG = "en_GB.UTF-8";
      LC_CTYPE = "en_GB.UTF-8";
      LC_ALL = "en_GB.UTF-8";
      EDITOR = "nvim";
      PAGER = "less -FirSwX";
      MANPAGER = "sh -c 'col -bx | ${pkgs.bat}/bin/bat -l man -p'";
    };
  };

  nixpkgs.config.permittedInsecurePackages = [
    "openssl-1.1.1v"
  ];

  fonts.fontconfig.enable = true;

  services = {
    # Screen lock
    # screen-locker = {
    #   enable = true;
    #   inactiveInterval = 10;
    #   lockCmd = "${pkgs.i3lock-fancy-rapid}/bin/i3lock-fancy-rapid 10 15";
    # };

    # Auto mount devices
    udiskie.enable = true;
  };

  # programs = shared-programs;

  wayland.windowManager.hyprland = {
    enable = true;
    enableNvidiaPatches = false;
    systemdIntegration = true;
    xwayland.enable = true;

    extraConfig = ''
      # window resize
      bind = ALT, q, exec, foot
    '';
    # settings = {
    #   input = {
    #     touchpad.disable_while_typing = false;
    #   };

    #   bind = let
    #     terminal = pkgs.foot;
    #   in [
    #     # Program bindings
    #     "CTRL,q,exec,${terminal}"
    #   ];
    # };
  };
}
