{
  inputs,
  pkgs,
  ...
}:
let
  user = "df";
  hostname = "iompar";
  system = "aarch64-darwin";
  homeDir =
    if pkgs.stdenv.isLinux then
      "/home/${user}"
    else if pkgs.stdenv.isDarwin then
      "/Users/${user}"
    else
      throw "Unsupported platform";
in
{
  _module.args = {
    inherit
      user
      hostname
      system
      homeDir
      ;
  };

  ids.uids.nixbld = 300;

  system.stateVersion = 5;

  nixpkgs.hostPlatform = system;

  imports = [
    inputs.agenix.nixosModules.default
    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew

    ./modules/nix.nix
    ./modules/nixpkgs.nix

    ./modules
    ./modules/agenix.nix
  ];

  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    autoMigrate = true;
    mutableTaps = true;
    user = "${user}";
    # taps = with inputs; {
    #   "homebrew/homebrew-core" = homebrew-core;
    #   "homebrew/homebrew-cask" = homebrew-cask;
    # };
  };
  homebrew =
    let
      pkgSets = import ./home-manager/packages.nix { inherit pkgs; };
    in
    {
      enable = true;

      onActivation = {
        cleanup = "uninstall";
        autoUpdate = true;
        upgrade = false;
      };

      global.autoUpdate = false;

      masApps = {
        "Coin Tick - Menu Bar Crypto" = 1141688067;
        "ColorSlurp" = 1287239339;
        "Unsplash Wallpapers" = 1284863847;
        "WireGuard" = 1451685025;
      };

      brews = pkgSets.osx-brews;

      caskArgs.no_quarantine = true;
      casks = pkgSets.osx-casks;
    };

  services.nix-daemon.enable = true;
  # nix.package = pkgs.nix;

  environment.shells = [ pkgs.fish ];
  # TODO: Is this needed?
  # nix-darwin doesn't change the shells so we do it here
  # system.activationScripts.postActivation.text = ''
  #   echo "setting up users' shells..." >&2

  #   ${lib.concatMapStringsSep "\n" (user: ''
  #     dscl . create /Users/${user.name} UserShell "${user.shell}"
  #   '') (lib.attrValues config.users.users)}
  # '';

  users.users.${user} = {
    name = "${user}";
    home = "/Users/${user}";
  };

  home-manager = {
    useGlobalPkgs = true;
    # useUserPackages = true; # If enabled, then home-manager apps aren't linked properly to /Users/X/.nix-profile/..
    extraSpecialArgs = {
      inherit inputs;
    };

    users.${user} =
      { pkgs, ... }:
      {
        _module.args = {
          inherit user hostname system;
        };

        imports = [
          ./home-manager
          ./home-manager/alacritty.nix
          ./home-manager/btop.nix
          ./home-manager/fish.nix
          ./home-manager/git.nix
          ./home-manager/neovim.nix
          ./home-manager/ssh.nix
          ./home-manager/starship.nix
          ./home-manager/tmux.nix
          ./home-manager/vscode.nix
        ];

        # Different location on OSX
        home.homeDirectory = pkgs.lib.mkForce "/Users/${user}";

        home.packages =
          let
            pkgSets = import ./home-manager/packages.nix { inherit pkgs; };
          in
          pkgSets.essentials-utils
          ++ pkgSets.essentials-dev
          ++ pkgSets.essentials-gui
          ++ pkgSets.osx
          ++ [
            inputs.agenix.packages."${pkgs.system}".default
          ];

        programs.fish = {
          enable = true;

          shellAbbrs = {
            # TODO: Drop tail abhaile
            os-switch = lib.mkMerge [
              (lib.mkIf pkgs.stdenv.hostPlatform.isLinux "sudo nixos-rebuild --flake ~/.dotfiles/#abhaile switch --impure")
              (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "/run/current-system/sw/bin/darwin-rebuild switch --flake ~/.dotfiles/#iompar --impure")
            ];
            hm-switch = "home-manager switch --flake $HOME/.dotfiles/#abhaile";
            fnix-shell = "nix-shell --run fish";

            brew = "/opt/homebrew/bin/brew";
            dprune = "docker system prune --volumes -fa";

            k = "kubectl";
            kctx = "kubectx";
            kns = "kubens";
          };

          functions = {
            certp = {
              description = "Prints cert certificate for a given domain using openssl";
              body = "echo | openssl s_client -showcerts -servername $argv[1] -connect $argv[1]:443 2>/dev/null | openssl x509 -inform pem -noout -text";
            };

            gitnuke = {
              description = "Nukes a branch or tag locally and on the origin remote.";
              body = ''
                git branch --list
                git show-ref --verify refs/tags/"$argv[1]" && git tag -d "$argv[1]"
                git show-ref --verify refs/heads/"$argv[1]" && git branch -D "$argv[1]"
                git push origin :"$argv[1]"
                git branch --list
              '';
            };

            # OSX Only

            show_hidden_files = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
              description = "Toggle (YES/NO) show hidden files in OSX Finder";
              body = ''
                switch $argv[1]
                  case YES
                    echo "[showHiddenFiles]: showing hidden files..."
                  case NO
                    echo "[showHiddenFiles]: re-hidding files..."
                  case '*'
                    echo "[showHiddenFiles]: unknown option $argv[1] - [YES|NO] options only"
                    exit 1
                end

                defaults write com.apple.finder AppleShowAllFiles $argv[1]

                echo "[showHiddenFiles]: relaunching Finder..."
                osascript -e 'tell application "Finder" to quit'
                osascript -e 'tell application "Finder" to activate'
              '';
            };

            reset_internet = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
              description = "Resets several internet services. Assumes en0 is main interface";
              body = ''
                echo "[resetInternet]: tear down en0..."
                sudo ifconfig en0 down
                echo "[resetInternet]: flushing routes..."
                sudo route flush
                echo "[resetInternet]: bring up en0..."
                sudo ifconfig en0 up
                echo "[resetInternet]: restart mDNSResponder..."
                sudo killall -HUP mDNSResponder
              '';
            };

            flush_DNS = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
              description = "Flush DNS service";
              body = ''
                echo "[flushDNS]: restart mDNSResponder..."
                sudo killall -HUP mDNSResponder
              '';
            };

            restart_bluetooth = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
              description = "Restart the OSX Bluetooth service";
              body = ''
                switch $argv[1]
                  case restart
                    echo "[restartBluetooth]: restarting bluetooth only..."
                  case on
                    echo "[restartBluetooth]: turning Bluetooth ON"
                    sudo defaults write /Library/Preferences/com.apple.Bluetooth.plist ControllerPowerState 1
                  case off
                    echo "[restartBluetooth]: turning Bluetooth OFF"
                    sudo defaults write /Library/Preferences/com.apple.Bluetooth.plist ControllerPowerState 0
                  case '*'
                    echo "[restartBluetooth]: unknown option $argv[1] - [restart|on|off] options only"
                    exit 1
                end

                sudo kextunload -b com.apple.iokit.BroadcomBluetoothHostControllerUSBTransport
                sudo kextload -b com.apple.iokit.BroadcomBluetoothHostControllerUSBTransport

                echo "[restartBluetooth]: done"
              '';
            };
          };

          loginShellInit = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin ''
            if test -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
              fenv source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
            end

            if test -e /nix/var/nix/profiles/default/etc/profile.d/nix.sh
              fenv source /nix/var/nix/profiles/default/etc/profile.d/nix.sh
            end
          '';
        };
      };
  };
}
