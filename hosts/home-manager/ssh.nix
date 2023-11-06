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
        IgnoreUnknown UseKeychain
        AddKeysToAgent yes
      ''
      (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin
        ''
          UseKeychain yes
        '')
    ];
  };
}
