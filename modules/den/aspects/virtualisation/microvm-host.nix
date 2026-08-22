# Host-side support for `sandvm` (per-project sandboxed microVMs for coding
# agents — see modules/den/hosts/sandvm.nix + docs/microvm-sandbox.md).
#
# sandvm VMs run *imperatively* (build the guest's `config.microvm.declaredRunner`
# and exec it directly), not through microvm.nix's systemd-managed
# `microvm.host`/`microvm.vms.*` path — so no `microvm.nixosModules.host`
# import is needed here. All this host needs is somewhere persistent for the
# guest's SSH host key to live (so it survives the guest's ephemeral rootfs
# across runs and `known_hosts`/VSCode Remote-SSH never see a changed
# identity), generated once up front to dodge a first-boot race between
# concurrent sandvm instances.
{
  den.aspects.virtualization.microvm-host.nixos =
    { pkgs, ... }:
    {
      # Owned by df, not root: sandvm's qemu process (and its built-in 9p
      # server for this share) runs as df, not root, so root:root 0700 here
      # would make the guest's sshd unable to read its own host key.
      systemd.tmpfiles.rules = [
        "d /var/lib/sandvm 0700 df users - -"
        "d /var/lib/sandvm/hostkey 0700 df users - -"
      ];

      # A binary cache in front of this host's own /nix/store, on loopback
      # only. Guests reach it at qemu's SLIRP gateway (http://10.0.2.2:5000 —
      # see nix.settings.substituters in virtualisation/microvm-guest.nix), so
      # anything abhaile has already built or downloaded is copied in at
      # loopback speed instead of being rebuilt or refetched from
      # cache.nixos.org. Guests already mount this exact store read-only, so
      # serving it to them grants nothing new — which is why it runs unsigned
      # (no signKeyPaths) and the guest sets require-sigs = false: no key to
      # manage just to talk to ourselves.
      services.harmonia.cache = {
        enable = true;
        settings.bind = "127.0.0.1:5000";
      };

      # Don't rely on the tmpfiles rule above having already run by the time
      # this fires — activation script ordering vs. tmpfiles isn't
      # guaranteed, so this makes its own directory too.
      system.activationScripts.sandvmHostkey = ''
        mkdir -p /var/lib/sandvm/hostkey
        if [ ! -f /var/lib/sandvm/hostkey/ssh_host_ed25519_key ]; then
          ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -C "sandvm" \
            -f /var/lib/sandvm/hostkey/ssh_host_ed25519_key
        fi
        chown -R df:users /var/lib/sandvm
      '';
    };
}
