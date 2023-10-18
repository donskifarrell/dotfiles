{
  pkgs,
  lib,
  ...
}: {
  ssh = {
    enable = true;

    # includes = ["~/.ssh/sshconfig.local"];

    extraConfig = lib.mkMerge [
      ''
        Host *
         AddKeysToAgent yes
      ''
      (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin
        ''
          UseKeychain yes
        '')
    ];
  };
}
