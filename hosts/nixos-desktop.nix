{
  pkgs,
  inputs,
  ...
}: let
  user = "df";
  hostname = "makati";
in {
  imports = [
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-gpu-amd
    inputs.hardware.nixosModules.common-pc-ssd

    agenix.nixosModules.default

    ./hardware/desktop.nix

    ./nixos/nix.nix
    ./nixos/nixos-label.nix
    ./nixos/nixpkgs.nix

    ./nixos/fonts.nix
    ./nixos/i18n.nix

    ../common/global
    ../common/users/misterio

    ../common/optional/ckb-next.nix
    ../common/optional/greetd.nix
    ../common/optional/pipewire.nix
    ../common/optional/quietboot.nix
    ../common/optional/lol-acfix.nix
    ../common/optional/starcitizen-fixes.nix
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
        "wheel" # Enable ‘sudo’ for the user.
        "docker"
        "networkmanager"
        "libvirtd"
      ];
      shell = pkgs.fish;
      openssh.authorizedKeys.keys = keys;
    };

    root = {
      openssh.authorizedKeys.keys = keys;
    };
  };

  programs = {
    adb.enable = true;
    dconf.enable = true;
    fish.enable = true;
  };

  home-manager.nixosModules.home-manager = {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.users.${user} = import [
      ./home-manager
    ]
  };

  environment.systemPackages = let
    themes = pkgs.callPackage ./config/sddm-themes.nix {};
  in [
    agenix.packages."${pkgs.system}".default # "x86_64-linux"
    pkgs.gitAndTools.gitFull
    pkgs.inetutils
    pkgs.micro
    pkgs.archiver
    pkgs.p7zip
    pkgs.curl
    pkgs.foot

    pkgs.wev
    pkgs.wlr-randr
    pkgs.libnotify
    pkgs.libinput
    themes.sddm-catppuccin-frappe
  ];
}
