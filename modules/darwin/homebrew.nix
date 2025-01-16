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
      "curl"
      "mas"
      "scrcpy" # always ahead of nixpkgs
    ];

    caskArgs.no_quarantine = true;
    casks = [
      "little-snitch"
      "maestral"

      # Browsers
      "brave-browser"
      "chromium"
      "firefox"
      "vivaldi"

      # Tools
      "appcleaner"
      "balenaetcher"
      "itsycal"
      "keepingyouawake"
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
