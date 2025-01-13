{
  config,
  lib,
  pkgs,
  ...
}:
{

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
}
