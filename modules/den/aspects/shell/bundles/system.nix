# shell.bundles.system — system/resource inspection: btop, htop, the disk-usage
# explorers (dua, dysk, ncdu), and busybox as a *fallback toolbox*.
{
  den.aspects.shell.bundles.system.homeManager =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.btop
        pkgs.dua
        pkgs.dysk
        pkgs.ncdu

        # Applet symlinks OFF (2026-08-26). Stock busybox installs ~400 of
        # them into the profile — `ping`, `ip`, `ps`, `tar`, `wget`, `df`,
        # `du`, `top`, `find`, `awk`, `sed`… — and a home-manager profile
        # comes *before* /run/current-system/sw/bin on PATH, so every one of
        # those shadowed the real tool with a cut-down applet. The symptom df
        # hit: `ping google.com` → "permission denied (are you root?)",
        # because busybox's ping opens a raw socket while iputils' uses an
        # unprivileged ICMP datagram socket (net.ipv4.ping_group_range covers
        # every gid here). Others were quieter: busybox `tar` has no
        # --ignore-failed-read, busybox `ip` no `-br`, busybox `ps` no `-p`.
        #
        # With this override the package ships only `bin/busybox`, so the
        # toolbox is still one `busybox <applet>` away and nothing is
        # shadowed.
        (pkgs.busybox.override { enableAppletSymlinks = false; })
      ];

      programs.htop.enable = true;
    };
}
