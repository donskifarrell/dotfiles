{
  lib,
  pkgs,
  ...
}:
{
  services.ssh-agent.enable = if pkgs.stdenv.isLinux then true else false;

  programs.ssh = {
    enable = true;

    # includes = [ "~/.ssh/sshconfig.local" ];
    # addKeysToAgent = "confirm";

    # extraConfig = lib.mkMerge [
    #   ''
    #     IgnoreUnknown UseKeychain
    #   ''
    #   (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin ''
    #     UseKeychain yes
    #   '')
    # ];
  };
}
