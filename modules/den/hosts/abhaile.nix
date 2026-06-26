# Host `abhaile` — df's AMD desktop workstation, migrated onto den.
#
# Same split as hosts/try.nix: den composes the feature set (desktop roles +
# this machine's real hardware aspects), while clan owns the disk layout and
# hardware report via the machine dir (machines/abhaile/{disko.nix,facter.json},
# auto-imported). So this host does NOT include hardware.facter /
# hardware.storage.disko. Exposed as `flake.nixosModules.abhaile-den` by
# bridge.nix; `intoAttr = []` keeps clan the sole builder of
# nixosConfigurations.abhaile.
{ den, ... }:
let
  authorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA6h5RafG9hYqgT3nviJO9P9eEUEAHJlIEqFWfoxFOP6";
in
{
  den.hosts.x86_64-linux.abhaile = {
    intoAttr = [ ]; # clan owns nixosConfigurations.abhaile
    users.df = { };
  };

  den.aspects.abhaile = {
    includes = with den.aspects; [
      # Real hardware (AMD desktop) — mirrors what short composed, minus the
      # facter/disko aspects (clan provides those from the machine dir).
      hardware.bluetooth
      hardware.cpu.amd
      hardware.cpu.auto-cpufreq
      hardware.firmware
      hardware.gpu.amd
      hardware.keyboard
      hardware.printing
      hardware.storage.ssd
      hardware.touchpad
      hardware.tweaks
      hardware.utils

      hardware.ledger

      virtualization.libvirt

      roles.default
      roles.workstation
      roles.dev
      roles.desktop
    ];

    nixos = _: {
      users.users.root.openssh.authorizedKeys.keys = [ authorizedKey ];
    };
  };
}
