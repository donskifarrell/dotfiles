{
  flake,
  pkgs,
  lib,
  ...
}:

{
  users.users =
    let
      myKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKdNislbiV21PqoaREbPATGeCj018IwKufVcgR4Ft9Fl london"
      ];
    in
    {
      root.openssh.authorizedKeys.keys = myKeys;

      "df" =
        {
          openssh.authorizedKeys.keys = myKeys;
          shell = pkgs.fish;
        }
        // lib.optionalAttrs pkgs.stdenv.isLinux {
          isNormalUser = true;
          initialHashedPassword = "";
          extraGroups = [
            "networkmanager"
            "wheel"
            "libvirtd"
            "kvm"
          ];
        };
    };

  programs.fish.enable = true;
}
