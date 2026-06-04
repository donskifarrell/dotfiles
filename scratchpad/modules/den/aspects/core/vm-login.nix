# Test-only convenience for `nixos-rebuild build-vm`.
#
# Everything here is under `virtualisation.vmVariant`, which ONLY applies to
# `system.build.vm` — the real `system.build.toplevel` (deploys) is untouched.
# Gives you an autologin console + SSH-able root/df so a build-vm boot is usable.
{
  den.aspects.core.vm-login.nixos = {
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
    };
  };
}
