{
  pkgs,
  lib,
  nixpkgs,
  inputs,
  ssh-keys,
  ...
}: let
  user = "df";
  hostname = "makati-qemu";
in {
  _module.args.user = user;

  imports = [
    ./hardware/qemu.nix

    ./modules/nix.nix
    ./modules/nixos-label.nix
    ./modules/nixpkgs.nix

    ./modules/i18n.nix
    ./modules/ssh.nix
    ./modules/sudo.nix
    ./modules/xdg.nix
  ];

  system.stateVersion = "23.05"; # Don't change this
  time.timeZone = "Asia/Singapore";

  # VM specific changes
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_6_1; # To fix an issue with ZFS compatibility
  virtualisation.vmVariant = {
    virtualisation = {
      forwardPorts = [
        {
          from = "host";
          host.port = 2222;
          guest.port = 22;
        }
      ];
      qemu.options = [
        "-device virtio-vga-gl"
        "-display sdl,gl=on,show-cursor=off"
        "-audio pa,model=hda"
        "-m 16G"
      ];
    };
    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = true;
      settings.PermitRootLogin = nixpkgs.lib.mkForce "yes";
    };
  };

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
  };

  security = {
    polkit.enable = true;
    rtkit.enable = true;
  };

  services = {
    dbus.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users = {
    "${user}" = {
      isNormalUser = true;
      initialHashedPassword = "password";
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
    fish.enable = true;
  };

  # home-manager.nixosModules.home-manager = {
  #   home-manager.useGlobalPkgs = true;
  #   home-manager.useUserPackages = true;
  #   home-manager.users.${user} = import [
  #     ./home-manager
  #   ];
  # };

  environment.systemPackages = with pkgs; [
    gitAndTools.gitFull
    inetutils
    micro
    p7zip
    curl
    wget
  ];
}
