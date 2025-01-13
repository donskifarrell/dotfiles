# Configuration for this repo
# See ./modules/flake-parts/config.nix for module options.
{
  pkgs,
  ...
}:
{
  me = {
    username = "df";
    homeDir = "/${if pkgs.stdenv.isDarwin then "Users" else "home"}/df";
    system = "${if pkgs.stdenv.isDarwin then "aarch64-darwin" else "x86_64-linux"}";
    sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKdNislbiV21PqoaREbPATGeCj018IwKufVcgR4Ft9Fl london";
  };
}
