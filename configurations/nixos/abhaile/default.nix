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

    (self + /modules/shared/agenix.nix)
    (self + /modules/shared/fonts.nix)
    (self + /modules/shared/i18n.nix)
    (self + /modules/shared/nix.nix)
    (self + /modules/shared/user.nix)

    self.nixosModules.bluetooth
    # self.nixosModules.bootlabel
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
  ];

  time.timeZone = "Europe/Dublin";
  networking.hostName = "abhaile";

  # To enable automounting with udiskie in home manager
  services.udisks2.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_6_12;

  # TODO: Remove - Debug random restart
  boot.crashDump.enable = true;
  services.journald.rateLimitBurst = 50000;
  services.journald.rateLimitInterval = "1s";
  services.journald.extraConfig = ''
    Storage=persistent
  '';
  services.sysstat.enable = true;

  # TODO: Remove overlay and fix in nix.nix file
  nixpkgs.overlays = [
    (final: prev: {
      # until #369069 gets merged: https://nixpk.gs/pr-tracker.html?pr=369069
      gnome-extension-manager = prev.gnome-extension-manager.overrideAttrs (old: {
        src = prev.fetchFromGitHub {
          owner = "mjakeman";
          repo = "extension-manager";
          rev = "v0.6.0";
          hash = "sha256-AotIzFCx4k7XLdk+2eFyJgrG97KC1wChnSlpLdk90gE=";
        };
        patches = [ ];
        buildInputs = with prev; [
          blueprint-compiler
          gtk4
          json-glib
          libadwaita
          libsoup_3
          libbacktrace
          libxml2
        ];
      });
    })
  ];

  # For home-manager to work.
  # https://github.com/nix-community/home-manager/issues/4026#issuecomment-1565487545
  # Common config is in modules/shared/user.nix
  users.users."${username}".isNormalUser = true;

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
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
    inputs.agenix.packages.x86_64-linux.default
    git
    nixfmt-rfc-style

    # TODO: Remove - Debug random restart
    linuxKernel.packages.linux_6_12.cpupower
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
