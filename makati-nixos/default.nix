{
  config,
  lib,
  inputs,
  pkgs,
  agenix,
  hyprland,
  ...
}: let
  user = "df";
  hostname = "makati";
  keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKdNislbiV21PqoaREbPATGeCj018IwKufVcgR4Ft9Fl london"];
in {
  imports = [
    # ./secrets.nix
    # ./disk-config.nix
    ../shared
    ../shared/cachix
    # ./vm/hardware-configuration.nix
    agenix.nixosModules.default
  ];

  # Use the systemd-boot EFI boot loader.
  boot = {
    loader = {
      systemd-boot.enable = true;
      systemd-boot.configurationLimit = 42;
      efi.canTouchEfiVariables = true;
    };
    initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"];
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = ["uinput" "kvm-amd"];
  };
  time.timeZone = "Asia/Singapore";
  networking = {
    hostName = hostname;
    networkmanager.enable = true;
    wireless.enable = false;
    firewall = {
      # 3389: RDP from OSX
      allowedTCPPorts = [3389];
      # allowedUDPPorts = [ ... ];
    };
    # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
    # (the default) this is the recommended approach. When using systemd-networkd it's
    # still possible to use this option, but it's recommended to use it in conjunction
    # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
    useDHCP = lib.mkDefault true;
  };
  nix = {
    auto-optimise-store = true;
    # nixPath = ["nixos-config=/home/${user}/.local/share/src/nixos-config:/etc/nixos"];
    settings.allowed-users = ["${user}"];
    settings.trusted-users = ["${user}"];
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 1w";
    };
  };
  programs = {
    # Needed for anything GTK related
    # dconf.enable = true;
    fish.enable = true;
    hyprland = {
      enable = true;
      package = hyprland.packages.${pkgs.system}.hyprland;
      xwayland = {
        enable = true;
      };
    };
    waybar = {
      enable = true;
    };
    thunar = {
      enable = true;
      plugins = with pkgs.xfce; [
        thunar-archive-plugin
        thunar-volman
      ];
    };
  };
  # XDG Portals
  xdg = {
    autostart.enable = true;
    portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal
        pkgs.xdg-desktop-portal-gtk
      ];
    };
  };
  services = {
    # Enable CUPS to print documents
    printing = {
      enable = true;
      drivers = [pkgs.samsung-unified-linux-driver];
    };
    pipewire = {
      enable = true;
      audio.enable = true;
      alsa.enable = false;
      alsa.support32Bit = false;
      pulse.enable = true;

      # use the example session manager (no others are packaged yet so this is enabled by default,
      # no need to redefine it in your config for now)
      #media-session.enable = true;
    };
    gvfs.enable = true; # Mount, trash, and other functionalities
    tumbler.enable = true; # Thumbnail support for images
    openssh = {
      enable = true;
      settings = {
        # Forbid root login through SSH.
        PermitRootLogin = "no";
      };
    };
    xserver = {
      enable = true;
      layout = "us";
      xkbVariant = "";
      libinput.enable = true;
      displayManager.gdm = {
        enable = true;
        wayland = true;
      };
    };
    dbus.enable = true;
    gnome = {
      sushi.enable = true;
      gnome-keyring.enable = true;
    };
  };
  sound.enable = true;
  hardware = {
    opengl.enable = true;
    pulseaudio.enable = false;
    # Crypto wallet support
    ledger.enable = true;
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
      ];
      shell = pkgs.fish;
      openssh.authorizedKeys.keys = keys;
    };
    root = {
      openssh.authorizedKeys.keys = keys;
    };
  };
  security = {
    # Don't require password for users in `wheel` group for these commands
    sudo = {
      enable = true;
      extraRules = [
        {
          commands = [
            {
              command = "${pkgs.systemd}/bin/reboot";
              options = ["NOPASSWD"];
            }
          ];
          groups = ["wheel"];
        }
      ];
    };
    polkit.enable = true;
    rtkit.enable = true;
  };
  fonts.fonts = with pkgs; [
    dejavu_fonts
    jetbrains-mono
    font-awesome
    noto-fonts
    noto-fonts-emoji
  ];
  i18n = {
    defaultLocale = "en_GB.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_GB.UTF-8";
      LC_IDENTIFICATION = "en_GB.UTF-8";
      LC_MEASUREMENT = "en_GB.UTF-8";
      LC_MONETARY = "en_GB.UTF-8";
      LC_NAME = "en_GB.UTF-8";
      LC_NUMERIC = "en_GB.UTF-8";
      LC_PAPER = "en_GB.UTF-8";
      LC_TELEPHONE = "en_GB.UTF-8";
      LC_TIME = "en_GB.UTF-8";
    };
  };
  environment.systemPackages = with pkgs; [
    agenix.packages."${pkgs.system}".default # "x86_64-linux"
    gitAndTools.gitFull
    inetutils
    micro
    unzip
    curl
    dunst
    foot
  ];
  system.stateVersion = "23.05"; # Don't change this
}
