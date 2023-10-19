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
  # TODO: Not always the case for VMs
  system = "x86_64-linux";
in {
  _module.args.user = user;
  _module.args.hostname = hostname;
  _module.args.system = system;

  imports = [
    inputs.home-manager.nixosModules.home-manager

    ./hardware/qemu.nix

    ./modules/nix.nix
    ./modules/nixos-label.nix
    ./modules/nixpkgs.nix

    ./modules
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
      _module.args.homeDir = "/home/${user}";
      _module.args.configDir = "/home/${user}/.config";

      imports = [
        ./home-manager
        ./home-manager/fish.nix
        ./home-manager/git.nix
        ./home-manager/neovim.nix
        ./home-manager/ssh.nix
        ./home-manager/starship.nix
        ./home-manager/tmux.nix
      ];

      home.homeDirectory = pkgs.lib.mkForce "/home/${user}";

      home.packages = let
        pkgSets = import ./home-manager/packages.nix {inherit pkgs;};
      in
        pkgSets.essentials-utils
        ++ pkgSets.essentials-dev
        ++ pkgSets.nixos;
    };
  };

  environment.systemPackages = with pkgs; [
    gitAndTools.gitFull
    inetutils
    micro
    p7zip
    curl
    wget
  ];
}
