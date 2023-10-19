# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  lib,
  config,
  pkgs,
  hostname,
  ...
}: {


  programs.fish = {
    shellAliases = {
      brew = "/opt/homebrew/bin/brew";

      dprune = "docker system prune --volumes -fa";
      k = "kubectl";
      kctx = "kubectx";
      kns = "kubens";
    };

    loginShellInit = ''
      if test -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        fenv source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
      end

      if test -e /nix/var/nix/profiles/default/etc/profile.d/nix.sh
        fenv source /nix/var/nix/profiles/default/etc/profile.d/nix.sh
      end

    '';

    interactiveShellInit = ''
      fzf_configure_bindings --directory=\ct
      set fzf_fd_opts --hidden --exclude=.git --exclude=Library

      set FORGIT_LOG_FZF_OPTS "--reverse"
      set FORGIT_GLO_FORMAT "%C(auto)%h%d %s %C(blue)%an %C(green)%C(bold)%cr"

      set GOBIN "/Users/${config.home.username}/go/bin"
      fish_add_path -pmP /Users/${config.home.username}/go/bin

    '';

    functions = {
      show_hidden_files = {
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

      reset_internet = {
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

      flush_DNS = {
        description = "Flush DNS service";
        body = ''
          echo "[flushDNS]: restart mDNSResponder..."
          sudo killall -HUP mDNSResponder
        '';
      };

      restart_bluetooth = {
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
  };

  programs.tmux = {
    extraConfig = ''
      # ----------------------
      # From home.nix
      # -----------------------

      set -s copy-command 'pbcopy'
    '';
  };

  programs.alacritty = {
    settings = {
      key_bindings = [
        {
          key = "K";
          mods = "Command";
          mode = "~Vi|~Search";
          chars = "f";
        }
        {
          key = "K";
          mods = "Command";
          mode = "~Vi|~Search";
          action = "ClearHistory";
        }
        {
          key = "Key0";
          mods = "Command";
          action = "ResetFontSize";
        }
        {
          key = "Equals";
          mods = "Command";
          action = "IncreaseFontSize";
        }
        {
          key = "Plus";
          mods = "Command";
          action = "IncreaseFontSize";
        }
        {
          key = "Minus";
          mods = "Command";
          action = "DecreaseFontSize";
        }
        {
          key = "V";
          mods = "Command";
          action = "Paste";
        }
        {
          key = "C";
          mods = "Command";
          action = "Copy";
        }
      ];
    };
  };

}
