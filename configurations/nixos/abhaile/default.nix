# See /modules/nixos/* for actual settings
# This file is just *top-level* configuration.
{ flake, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-cpu-amd-zenpower
    inputs.nixos-hardware.nixosModules.common-cpu-amd-raphael-igpu
    inputs.nixos-hardware.nixosModules.common-pc-ssd

    ./hardware-configuration.nix

    inputs.agenix.nixosModules.default

    self.nixosModules.bluetooth
    self.nixosModules.bootlabel
    self.nixosModules.networking
    self.nixosModules.printing
    self.nixosModules.shared
    self.nixosModules.sound
    self.nixosModules.ssh
    self.nixosModules.xdg

    # GUI
    self.nixosModules.fonts
    self.nixosModules.gnome
    # self.nixosModules.xserver

    # (self + /modules/nixos/linux/distributed-build.nix)
  ];

  time.timeZone = "Europe/Dublin";
  networking.hostName = "abhaile";

  # For home-manager to work.
  # https://github.com/nix-community/home-manager/issues/4026#issuecomment-1565487545
  # Common config is in user.nix
  users.users."df".isNormalUser = true;

  # Enable home-manager for "df" user
  home-manager.users."df" = {
    imports = [ (self + /configurations/home/df.nix) ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
