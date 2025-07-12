# See /modules/nixos/* for actual settings
# This file is just *top-level* configuration.
{ flake, pkgs, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;

  username = "df";
in
{
  imports = [
    (self + /modules/flake-parts/config.nix)

    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-cpu-amd-zenpower
    inputs.nixos-hardware.nixosModules.common-cpu-amd-raphael-igpu
    inputs.nixos-hardware.nixosModules.common-pc-ssd

    ./hardware-configuration.nix

    inputs.agenix.nixosModules.default
    inputs.nix-index-database.nixosModules.nix-index
    inputs.nix-flatpak.nixosModules.nix-flatpak

    (self + /modules/shared/agenix.nix)
    (self + /modules/shared/fonts.nix)
    (self + /modules/shared/i18n.nix)
    (self + /modules/shared/nix.nix)
    (self + /modules/shared/user.nix)

    # self.nixosModules.bootlabel
    self.nixosModules.bluetooth
    self.nixosModules.flatpak
    self.nixosModules.gpu
    self.nixosModules.networking
    self.nixosModules.printing
    self.nixosModules.sound
    self.nixosModules.ssh
    self.nixosModules.sudo
    self.nixosModules.xdg

    # GUI
    (self + /modules/shared/fonts.nix)
    self.nixosModules.gnome
    self.nixosModules.xserver

    # Gaming
    self.nixosModules.steam
  ];

  time.timeZone = "Europe/Dublin";
  networking.hostName = "abhaile";

  # To enable automounting with udiskie in home manager
  services.udisks2.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # TODO: Remove - Debug random restart
  boot.crashDump.enable = true;
  services.journald.rateLimitBurst = 50000;
  services.journald.rateLimitInterval = "1s";
  services.journald.extraConfig = ''
    Storage=persistent
  '';
  services.sysstat.enable = true;

  systemd = {
    # To configure GPU
    packages = with pkgs; [ lact ];
    services.lactd.wantedBy = [ "multi-user.target" ];
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="kvmfr", OWNER="${username}", GROUP="kvm", MODE="0660"
  '';

  # For home-manager to work.
  # https://github.com/nix-community/home-manager/issues/4026#issuecomment-1565487545
  # Common config is in modules/shared/user.nix
  users.users."${username}".isNormalUser = true;
  users.groups.libvirtd.members = [ username ];

  virtualisation.spiceUSBRedirection.enable = true;
  virtualisation.libvirtd = {
    enable = true;

    qemu = {
      package = pkgs.qemu_kvm;
      ovmf.enable = true;
      swtpm.enable = true;

      verbatimConfig = ''
        cgroup_device_acl = [
            "/dev/null", "/dev/full", "/dev/zero",
            "/dev/random", "/dev/urandom",
            "/dev/ptmx", "/dev/kvm",
            "/dev/kvmfr0"
        ]
      '';
    };
  };

  security.tpm2.enable = true;

  home-manager = {
    extraSpecialArgs = {
      inherit inputs;
    };

    # Enable home-manager for user
    users."${username}" = {
      imports = [
        (self + /modules/flake-parts/config.nix)

        inputs.nix-index-database.hmModules.nix-index
        (self + /configurations/home/${username}.nix)
      ];
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    inputs.agenix.packages.x86_64-linux.default
    git
    nixfmt-rfc-style
    lact
    pciutils

    # TODO: Remove - Debug random restart
    linuxKernel.packages.linux_6_12.cpupower

    # Gaming
    mangohud
    looking-glass-client
    virt-viewer
    swtpm
    bridge-utils
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
