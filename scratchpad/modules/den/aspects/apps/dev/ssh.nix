# Ported from modules/home/ssh.nix. Client config + agent. Includes the
# clan-managed `sshconfig.local` (materialised by the secrets layer, plan 2.3).
{
  den.aspects.apps.dev.ssh.homeManager =
    { lib, pkgs, ... }:
    {
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;

        matchBlocks."*" = {
          addKeysToAgent = "confirm";
          forwardAgent = false;
          compression = false;
          serverAliveCountMax = 3;
          hashKnownHosts = true;
          userKnownHostsFile = "~/.ssh/known_hosts";
          controlMaster = "auto";
          controlPath = "~/.ssh/master-%r@%n:%p";
          controlPersist = "10m";
        };

        matchBlocks."root@localhost root@127.0.0.1 root@::1".forwardAgent = true;

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
