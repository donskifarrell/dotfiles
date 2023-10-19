{
  pkgs,
  lib,
  nixpkgs,
  inputs,
  ssh-keys,
  ...
}: let
  user = "df";
  hostname = "makati";
  system = "x86_64-linux";
in {
  _module.args.user = user;
  _module.args.hostname = hostname;
  _module.args.system = system;

  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-pc-ssd

    inputs.agenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager

    ./hardware/desktop.nix

    ./modules/nix.nix
    ./modules/nixos-label.nix
    ./modules/nixpkgs.nix

    ./modules
    ./modules/fonts.nix
    ./modules/gnome.nix
    ./modules/i18n.nix
    ./modules/sound.nix
    ./modules/ssh.nix
    ./modules/sudo.nix
    # ./modules/xdg.nix
    ./modules/xserver.nix
    # ./modules/hyprland.nix
  ];

  system.stateVersion = "23.05"; # Don't change this
  time.timeZone = "Asia/Singapore";

  nix = {
    settings = {
      allowed-users = ["${user}"];
      trusted-users = ["${user}"];
    };
  };

  networking = {
    hostName = "${hostname}";
    networkmanager.enable = true;
    wireless.enable = false;
    firewall = {
      # 3389: RDP from OSX
      allowedTCPPorts = [3389];
    };
  };

  security = {
    polkit.enable = true;
    rtkit.enable = true;
    pam.services.swaylock = {};
  };

  services = {
    # Enable CUPS to print documents
    printing = {
      enable = true;
      #  drivers = [pkgs.samsung-unified-linux-driver];
    };
    gvfs.enable = true; # Mount, trash, and other functionalities
    tumbler.enable = true; # Thumbnail support for images
    dbus.enable = true;
  };

  hardware = {
    bluetooth.enable = true;
    pulseaudio.enable = false;

    opengl = {
      enable = true;
      extraPackages = with pkgs; [amdvlk];
      driSupport = true;
    };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users = {
    "${user}" = {
      isNormalUser = true;
      initialHashedPassword = "";
      description = "${user}@${hostname}";
      extraGroups = [
        "docker"
        "libvirtd"
        "networkmanager"
        "wheel" # Enable ‘sudo’ for the user.
      ];
      shell = pkgs.fish;
      openssh.authorizedKeys.keys = ssh-keys;
    };

    root = {
      openssh.authorizedKeys.keys = ssh-keys;
    };
  };

  programs = {
    adb.enable = true;
    dconf.enable = true;
    fish.enable = true;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs;
    };

    users.${user} = {pkgs, ...}: {
      _module.args.user = user;
      _module.args.hostname = hostname;
      _module.args.system = system;

      imports = [
        ./home-manager
        ./home-manager/alacritty.nix
        ./home-manager/fish.nix
        ./home-manager/git.nix
        ./home-manager/neovim.nix
        ./home-manager/ssh.nix
        ./home-manager/starship.nix
        ./home-manager/tmux.nix
        ./home-manager/vscode.nix
      ];

      home.packages = let
        pkgSets = import ./home-manager/packages.nix {inherit pkgs;};
      in
        pkgSets.essentials-utils
        ++ pkgSets.essentials-dev
        ++ pkgSets.essentials-gui
        ++ pkgSets.nixos
        ++ pkgSets.nixos-gnome;
    };
  };

  environment.systemPackages = [
    inputs.agenix.packages."${pkgs.system}".default # "x86_64-linux"

    pkgs.archiver
    pkgs.curl
    pkgs.foot
    pkgs.gitAndTools.gitFull
    pkgs.inetutils
    pkgs.libinput
    pkgs.libnotify
    pkgs.micro
    pkgs.p7zip
    pkgs.wev
    pkgs.wlr-randr
  ];
}
