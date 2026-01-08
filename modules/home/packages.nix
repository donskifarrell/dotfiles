{
  config.flake.homeModules.packages =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      inherit (lib) mkEnableOption mkOption types;
      cfg = config.my.packages;

      # Keys become option names: my.packages.<key>.enable
      catalog = {
        # Security / Accounts
        _1password-cli = pkgs._1password-cli;
        _1password-gui = pkgs._1password-gui;
        authenticator = pkgs.authenticator;

        # Browsers
        brave = pkgs.brave;
        chromium = pkgs.chromium;
        firefox = pkgs.firefox;
        vivaldi = pkgs.vivaldi;

        # Apps
        maestral-gui = pkgs.maestral-gui;
        slack = pkgs.slack;

        # Media
        ffmpeg = pkgs.ffmpeg;
        imagemagick = pkgs.imagemagick;
        krita = pkgs.krita;
        vlc = pkgs.vlc;

        # Tools
        curl = pkgs.curl;
        dig = pkgs.dig;
        exiftool = pkgs.exiftool;
        inetutils = pkgs.inetutils;
        lsof = pkgs.lsof;
        p7zip = pkgs.p7zip;
        unrar = pkgs.unrar;
        unzip = pkgs.unzip;
        wget = pkgs.wget;
        wl-clipboard = pkgs.wl-clipboard;

        # Dev
        android-tools = pkgs.android-tools;
        bore-cli = pkgs.bore-cli;
        devenv = pkgs.devenv;
        glogg = pkgs.glogg;
        insomnia = pkgs.insomnia;
        nixfmt-rfc-style = pkgs.nixfmt-rfc-style;
        sqlitebrowser = pkgs.sqlitebrowser;
      };

      # Generate sub-options: my.packages.<name>.enable
      perPkgOptions = lib.mapAttrs (_name: _pkg: {
        enable = mkEnableOption "Install package ${_name}";
      }) catalog;

      enabledPkgs = lib.attrValues (
        lib.filterAttrs (name: _pkg: (cfg.enableAll or false) || (cfg.${name}.enable or false)) catalog
      );

    in
    {
      options.my.packages = {
        enableAll = mkOption {
          type = types.bool;
          default = false;
          description = "Enable all packages in this catalog.";
        };
      }
      // perPkgOptions;

      config.home.packages = enabledPkgs;
    };
}
