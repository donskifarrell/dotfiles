# Ported from modules/home/ssh.nix. Client config + agent. Includes
# `sshconfig.local`, materialised into ~/.ssh by the sops secrets.user aspect.
{
  den.aspects.core.network.ssh.homeManager =
    { lib, pkgs, ... }:
    {
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        # startAgent = true;

        matchBlocks."*" = {
          addKeysToAgent = "confirm";

          forwardAgent = false;
          compression = false;

          serverAliveCountMax = 3;

          hashKnownHosts = true;
          userKnownHostsFile = "~/.ssh/known_hosts";

          # Multiplexing
          controlMaster = "auto";
          controlPath = "~/.ssh/master-%r@%n:%p";
          controlPersist = "10m";
        };

        matchBlocks."root@localhost root@127.0.0.1 root@::1".forwardAgent = true;

        # macOS compatibility / keychain integration
        extraConfig = lib.mkMerge [
          ''
            Include ~/.ssh/sshconfig.local

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
