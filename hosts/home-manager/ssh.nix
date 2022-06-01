{
  lib,
  pkgs,
  ...
}: {
  programs.ssh = {
    enable = true;

    includes = ["~/.ssh/sshconfig.local"];

    extraConfig = lib.mkMerge [
      ''
        AddKeysToAgent yes
      ''
      (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin
        ''
          UseKeychain yes
        '')
    ];
  };
}
