{
  homebrew = {
    enable = true;

    onActivation = {
      cleanup = "uninstall";
      autoUpdate = true;
      upgrade = false;
    };

    global.autoUpdate = false;

    masApps = {
      "ColorSlurp" = 1287239339;
      "Unsplash Wallpapers" = 1284863847;
      "WireGuard" = 1451685025;
    };

    brews = [
      # Tools
      "curl"
      "exiftool"
      "ffmpeg"
      "imagemagick"
      "lsof"
      "mas"
      "p7zip"
      "scrcpy"
      "trippy"
      "wget"
    ];

    caskArgs.no_quarantine = true;
    casks = [
      "little-snitch@5"
      "maestral"

      # Browsers
      "brave-browser"
      "chromium"
      "firefox"
      "vivaldi"

      # Apps
      "appcleaner"
      "balenaetcher"
      "itsycal"
      "keepingyouawake"
      "krita"
      "libreoffice"
      "obsidian"
      "openmtp"
      "raycast"
      "rectangle"
      "skype"
      "slack"
      "steam"
      "sublime-text"
      "the-unarchiver"
      "vlc"

      # Dev
      "android-studio"
      "postman"
      "utm"
    ];
  };
}
