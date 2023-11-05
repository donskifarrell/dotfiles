{
  inputs,
  lib,
  nixpkgs,
  pkgs,
  ssh-keys,
  ...
}: let
  user = "df";
  hostname = "makati";
  system = "x86_64-linux";
  homeDir =
    if pkgs.stdenv.isLinux
    then "/home/${user}"
    else if pkgs.stdenv.isDarwin
    then "/Users/${user}"
    else throw "Unsupported platform";
in {
  _module.args = {
    inherit user hostname system homeDir;
  };

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
    ./modules/agenix.nix
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

    # TODO: what is this option?
    # udiskie.enable = true; # Auto mount devices

    # TODO: media keys
    # playerctld.enable = true;
  };

  hardware = {
    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;

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
    # useUserPackages = true; # If enabled, then home-manager apps aren't linked properly to /Users/X/.nix-profile/..
    extraSpecialArgs = {
      inherit inputs;
    };

    users.${user} = {pkgs, ...}: {
      _module.args = {
        inherit user hostname system;
      };

      imports = [
        ./home-manager
        ./home-manager/alacritty.nix
        ./home-manager/btop.nix
        ./home-manager/electron.nix
        ./home-manager/fish.nix
        ./home-manager/git.nix
        ./home-manager/gtk.nix
        # ./home-manager/hyprland.nix
        ./home-manager/neovim.nix
        ./home-manager/rofi.nix
        ./home-manager/ssh.nix
        ./home-manager/starship.nix
        ./home-manager/tmux.nix
        ./home-manager/vscode.nix
        # ./home-manager/waybar.nix
      ];

      home.homeDirectory = pkgs.lib.mkForce "/home/${user}";

      home.packages = let
        pkgSets = import ./home-manager/packages.nix {inherit pkgs;};
      in
        pkgSets.essentials-utils
        ++ pkgSets.essentials-dev
        ++ pkgSets.essentials-gui
        ++ pkgSets.essentials-x86-gui
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
