# Test-only convenience for `nixos-rebuild build-vm`.
#
# Everything here is under `virtualisation.vmVariant`, which ONLY applies to
# `system.build.vm` — the real `system.build.toplevel` (deploys) is untouched.
# Gives you an autologin console + SSH-able root/df, plus enough CPU/RAM and a
# GL-accelerated virtio GPU, so a build-vm boot is actually usable.
{
  den.aspects.virtualisation.vm-login.nixos = {
    virtualisation.vmVariant = {
      # Throwaway creds — VM variant only.
      users.users.root.initialPassword = "root";
      users.users.df.initialPassword = "df";

      # Drop straight into a df shell on the console.
      services.getty.autologinUser = "df";

      # Forward host :2222 -> guest :22 so `ssh -p 2222 df@localhost` works.
      virtualisation.forwardPorts = [
        {
          from = "host";
          host.port = 2222;
          guest.port = 22;
        }
      ];

      # The build-vm defaults (1 core / 1 GiB, no GPU) leave GNOME software-
      # rendered via llvmpipe — that's the laggy pointer + sluggish apps. Give
      # it room and a virtio GPU with host GL passthrough (virgl) so Shell is
      # hardware-accelerated. Tune cores/memorySize to your host.
      virtualisation.cores = 4;
      virtualisation.memorySize = 4096; # MiB
      # Build-vm writes copied closures into a writable overlay on short.qcow2;
      # the ~1 GiB default fills instantly on a GNOME push. qcow2 is sparse, so
      # this cap is virtually free until used. Changing it needs a fresh qcow2.
      virtualisation.diskSize = 32768; # MiB (32 GiB)
      virtualisation.qemu.options = [
        "-vga none" # drop the default emulated std VGA…
        "-device virtio-vga-gl" # …use a virgl-capable virtio GPU instead
        "-display gtk,gl=on,grab-on-hover=on"
      ];
    };
  };
}
