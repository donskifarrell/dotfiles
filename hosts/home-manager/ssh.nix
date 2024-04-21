{
  lib,
  pkgs,
  ...
}: {
  programs.ssh = {
    enable = true;

    addKeysToAgent = "confirm";

    includes = ["~/.ssh/sshconfig.local"];

    extraConfig = lib.mkMerge [
      ''
        IgnoreUnknown UseKeychain
      ''
      (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin
        ''
          UseKeychain yes
        '')
    ];
  };
}
