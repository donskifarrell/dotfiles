# clan machine `try` — runs the graduated den composition.
#
# The den feature set is composed in modules/den/hosts/try.nix and exposed as
# `modules.nixosModules.try-den` by modules/den/bridge.nix. clan auto-imports
# this machine dir's disko.nix + facter.json (generated via `clan machines
# init-hardware-config` / `clan templates apply disk`), so they aren't imported
# here.
{ modules, lib, ... }:
{
  imports = [ modules.nixosModules.try-den ];

  # Lets the config evaluate/build before facter.json exists. Once
  # `clan machines init-hardware-config` writes machines/try/facter.json, the
  # facter module sets the real value and overrides this default.
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
