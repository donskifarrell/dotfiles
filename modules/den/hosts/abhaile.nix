# Host `abhaile` — df's AMD desktop workstation, on Den + sops-nix.
#
# Phase 3: Den is the SOLE builder of `nixosConfigurations.abhaile` (intoAttr
# defaults to [ "nixosConfigurations" "abhaile" ]). The machine dir was removed
# from `machines/` (so clan no longer discovers/builds abhaile); its disk layout
# and hardware report now live in `hosts/abhaile/{disko.nix,facter.json}` and are
# imported here via the den hardware.storage.disko / hardware.facter aspects.
{ den, inputs, ... }:
let
  authorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA6h5RafG9hYqgT3nviJO9P9eEUEAHJlIEqFWfoxFOP6";

  # Emergency console access hash (was clan's public emergency-access "value";
  # boot.initrd.systemd.emergencyAccess takes the hash as a literal baked into
  # the initrd — it cannot be a sops file path).
  emergencyHash = "$6$uF.QGfonH/uvh6j.$LJW8DxXZHVx9uTmzrK5U9ZNfv5gd2ld2Lb.PpWPSXgDBfRFmAuWvCXx.x6ZGYgyXTM9N4cFbJMtwccglgdPkb0";
in
{
  den.hosts.x86_64-linux.abhaile = {
    # intoAttr defaults to [ "nixosConfigurations" "abhaile" ] -> Den emits it.
    users.df = { };
  };

  den.aspects.abhaile = {
    includes = with den.aspects; [
      # Real hardware (AMD desktop).
      hardware.bluetooth
      hardware.cpu.amd
      hardware.cpu.auto-cpufreq
      hardware.firmware
      hardware.gpu.amd
      hardware.gpu.rocm # GPU-compute diagnostics (rocminfo/vulkaninfo/…)
      hardware.keyboard
      hardware.printing
      hardware.storage.ssd
      hardware.touchpad
      hardware.tweaks
      hardware.utils

      hardware.ledger

      # Now Den-owned (was clan's machine-dir auto-import).
      hardware.facter
      hardware.storage.disko

      virtualization.libvirt

      roles.default
      roles.workstation
      roles.dev
      roles.desktop

      # sops-nix secrets + consumers.
      secrets.sops # base decryption wiring (host ssh key -> age)
      secrets.abhaile # df/root password-hash secrets
      secrets.home # df's ~/.ssh + ~/.config/git files from shared.yaml

      services.tailscale # tailscale peer (declares its own authkey secret)
      services.llm # llama.cpp vulkan+rocm on the RX 9070 (benchmarked on-box)
    ];

    nixos =
      { config, lib, ... }:
      {
        imports = [
          # disko.devices layout + the 172K facter hardware report.
          (inputs.self + "/hosts/abhaile/disko.nix")
        ];

        facter.reportPath = inputs.self + "/hosts/abhaile/facter.json";
        nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

        users.users.root.openssh.authorizedKeys.keys = [ authorizedKey ];

        # Passwords from sops-nix (replaces clan's users module). Den is now the
        # sole builder, so there is no clan definition to collide with.
        users.users.df.hashedPasswordFile = config.sops.secrets."abhaile-df-password-hash".path;
        users.users.root.hashedPasswordFile = config.sops.secrets."abhaile-root-password-hash".path;

        # Emergency console access (replaces clan emergency-access). abhaile uses
        # systemd-initrd, so this is the supported one-liner.
        boot.initrd.systemd.emergencyAccess = emergencyHash;
      };
  };
}
