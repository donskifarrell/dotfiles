{
  pkgs,
  inputs,
  ...
}: let
  user = "df";
  hostname = "manila";
in {
  imports = [
    nix-homebrew.darwinModules.nix-homebrew
    ./modules/nix.nix
  ];

  nix-homebrew = {
    enable = true;
    user = "${user}";
    taps = {
      "homebrew/homebrew-core" = homebrew-core;
      "homebrew/homebrew-cask" = homebrew-cask;
    };
    mutableTaps = false;
    autoMigrate = true;
  };
}
