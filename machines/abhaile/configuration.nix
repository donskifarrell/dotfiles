{ modules, lib, ... }:
{
  imports = [ modules.nixosModules.abhaile-den ];

  # facter.json (auto-imported by clan from this dir) sets the real value;
  # this mkDefault just lets the config evaluate if facter is ever absent.
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
