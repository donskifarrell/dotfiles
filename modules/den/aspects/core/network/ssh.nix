# Ported from modules/home/ssh.nix. Client config + agent. Includes
# `sshconfig.local`, materialised into ~/.ssh by the sops secrets.home aspect.
{
  den.aspects.core.network.ssh.homeManager =
    { lib, pkgs, ... }:
    {
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        # startAgent = true;

        # `settings` replaced the now-deprecated `matchBlocks` alias; keys are
        # OpenSSH directive names, and the `"*"` default block is rendered last
        # (so the specific root@localhost block below wins on ForwardAgent).
        settings."*" = {
          AddKeysToAgent = "confirm";

          ForwardAgent = false;
          Compression = false;

          ServerAliveCountMax = 3;

          HashKnownHosts = true;
          UserKnownHostsFile = "~/.ssh/known_hosts";

          # Multiplexing
          ControlMaster = "auto";
          ControlPath = "~/.ssh/master-%r@%n:%p";
          ControlPersist = "10m";
        };

        settings."root@localhost root@127.0.0.1 root@::1".ForwardAgent = true;

        # macOS compatibility / keychain integration
        extraConfig = lib.mkMerge [
          ''
            Include ~/.ssh/sshconfig.local
            # sandvm (docs/microvm-sandbox.md) writes its per-instance Host
            # blocks here at runtime — this directory itself isn't
            # home-manager-managed (unlike this file), so it stays writable.
            Include ~/.ssh/config.d/*

            IgnoreUnknown UseKeychain
          ''
          (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin ''
            UseKeychain yes
          '')
        ];
      };

      services.ssh-agent.enable = pkgs.stdenv.isLinux;
    };
}
