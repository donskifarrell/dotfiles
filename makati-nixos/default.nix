{
  config,
  lib,
  inputs,
  pkgs,
  agenix,
  hyprland,
  user,
  hostname,
  keys,
  vm ? false,
  ...
}: {
  imports = [
    # ./secrets.nix
    # ./disk-config.nix
    ../shared
    ../shared/cachix
    agenix.nixosModules.default
  ];

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
  };
  nixpkgs.config.permittedInsecurePackages = [
    "openssl-1.1.1w"
  ];
  nix = {
    settings.auto-optimise-store = true;
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
      enable = false;
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
      wireplumber.enable = true;

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
      desktopManager.gnome.enable = true;
      displayManager.sddm = {
        enable = true;
        enableHidpi = true;
        # https://github.com/sddm/sddm/blob/develop/data/man/sddm.conf.rst.in
        settings = {
          General = {
            DisplayServer = "wayland";
          };
        };

        theme = "catppuccin-frappe";
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
  environment.systemPackages = let
    themes = pkgs.callPackage ./custom/sddm-themes.nix {};
  in [
    agenix.packages."${pkgs.system}".default # "x86_64-linux"
    pkgs.gitAndTools.gitFull
    pkgs.inetutils
    pkgs.micro
    pkgs.unzip
    pkgs.curl
    pkgs.dunst
    pkgs.foot
    # pkgs.xdg-desktop-portal-hyprland
    pkgs.qt6.qtwayland
    pkgs.qt6.qt5compat
    pkgs.libsForQt5.qt5.qtwayland
    pkgs.libsForQt5.qt5.qtgraphicaleffects
    pkgs.libsForQt5.qt5.qtsvg
    pkgs.libsForQt5.qt5.qtquickcontrols2
    pkgs.swaynotificationcenter
    pkgs.wev
    pkgs.nwg-look
    pkgs.wlr-randr
    themes.sddm-catppuccin-frappe
  ];
  environment.gnome.excludePackages = with pkgs; [
    gnome.totem
    gnome.epiphany
    gnome.gnome-calendar
    gnome.gnome-clocks
    gnome.gnome-contacts
    gnome.gnome-maps
    gnome.gnome-weather
    gnome.gnome-clocks
  ];
  system.stateVersion = "23.05"; # Don't change this
}
