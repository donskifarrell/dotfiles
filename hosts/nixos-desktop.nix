{
  pkgs,
  inputs,
  ssh-keys,
  ...
}: let
  user = "df";
  hostname = "makati";
in {
  _module.args.user = user;

  imports = [
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-gpu-amd
    inputs.hardware.nixosModules.common-pc-ssd

    agenix.nixosModules.default
    home-manager.nixosModules.home-manager

    ./hardware/desktop.nix

    ./modules/nix.nix
    ./modules/nixos-label.nix
    ./modules/nixpkgs.nix

    ./modules/fonts.nix
    ./modules/gnome.nix
    # ./modules/hyprland.nix
    ./modules/i18n.nix
    ./modules/sound.nix
    ./modules/ssh.nix
    ./modules/sudo.nix
    ./modules/xdg.nix
    ./modules/xserver.nix
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
    users.${user} = { pkgs, …}: {
      imports = [
        
      ]

      # home.packages = [ pkgs.btop ];
    };
  };

  environment.systemPackages = let
    themes = pkgs.callPackage ./config/sddm-themes.nix {};
  in [
    pkgs.gitAndTools.gitFull
    pkgs.inetutils
    pkgs.micro
    pkgs.p7zip
    pkgs.curl

    agenix.packages."${pkgs.system}".default # "x86_64-linux"
    pkgs.archiver
    pkgs.foot
    pkgs.wev
    pkgs.wlr-randr
    pkgs.libnotify
    pkgs.libinput
    themes.sddm-catppuccin-frappe
  ];
}
