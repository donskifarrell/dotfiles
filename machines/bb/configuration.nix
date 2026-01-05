{ config, pkgs, ... }:
{
  networking.hostName = "vm-bb";

  services.openssh.enable = true;

  users.users.root.initialPassword = "changeme";

  services.qemuGuest.enable = true;

  system.stateVersion = "25.11";
}
