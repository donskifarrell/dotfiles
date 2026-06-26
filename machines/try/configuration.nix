# clan machine `try` — runs the graduated den composition.
#
# The den feature set is composed in modules/den/hosts/try.nix and exposed as
# `modules.nixosModules.try-den` by modules/den/bridge.nix. clan auto-imports
# this machine dir's disko.nix + facter.json (generated via `clan machines
# init-hardware-config` / `clan templates apply disk`), so they aren't imported
# here.
{ modules, ... }:
{
  imports = [ modules.nixosModules.try-den ];

  # clan normally gets this from the machine's facter.json (generated at
  # install time via `clan machines init-hardware-config`). Set it explicitly so
  # the config evaluates/builds before the VM exists; facter sets the same value.
  nixpkgs.hostPlatform = "x86_64-linux";
}
