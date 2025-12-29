{
  config.flake.homeModules.packages =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        # Security / Accounts
        _1password-cli
        _1password-gui
        authenticator

        # Browsers
        brave
        chromium
        firefox
        vivaldi

        # Apps
        maestral-gui
        slack

        # Media
        ffmpeg
        imagemagick
        krita
        vlc

        # Tools
        curl
        dig
        exiftool
        inetutils
        lsof
        p7zip
        unrar
        unzip
        wget

        # Dev
        android-tools
        bore-cli
        glogg
        insomnia
        nixfmt-rfc-style
        sqlitebrowser
      ];
    };
}
