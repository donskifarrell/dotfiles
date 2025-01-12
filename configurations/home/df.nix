{
  flake,
  pkgs,
  lib,
  ...
}:
let
  inherit (flake) inputs;
  inherit (inputs) self;

  homeDir = "/${if pkgs.stdenv.isDarwin then "Users" else "home"}/df";
in
{
  imports = [
    self.homeModules.direnv
    self.homeModules.git
    self.homeModules.nix
    self.homeModules.ssh
  ];

  home = {
    stateVersion = "24.11";

    homeDirectory = lib.mkDefault homeDir;
    username = "df";

    sessionVariables = {
      LANG = "en_GB.UTF-8";
      LC_CTYPE = "en_GB.UTF-8";
      LC_ALL = "en_GB.UTF-8";
      PAGER = "less -FirSwX";
      MANPAGER = "sh -c 'col -bx | ${pkgs.bat}/bin/bat -l man -p'";
      MANROFFOPT = "-c";

      XDG_CACHE_DIR = "${homeDir}/.cache";
      XDG_CACHE_HOME = "${homeDir}/.cache";
      XDG_CONFIG_HOME = "${homeDir}/.config";
      XDG_DATA_HOME = "${homeDir}/.local/share";
    };

    sessionPath = [ "${homeDir}/dev/bin" ];
  };

  programs = {
    bat.enable = true;
    direnv.enable = true;
    eza.enable = true;
    fish.enable = true;
    fzf.enable = true;

    zoxide = {
      enable = true;
      enableFishIntegration = true;
    };

    firefox.enable = true;
    git.enable = true;
    vscode.enable = true;
  };

  home.packages = with pkgs; [
    age
  ];
}
