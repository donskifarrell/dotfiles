{
  config,
  lib,
  pkgs,
  ...
}: {
  home = {
    file."fish-catppuccin-macchiato" = {
      source = "${config.home.homeDirectory}/.dotfiles/hosts/config/theme/fish-catppuccin-macchiato.theme";
      target = "${config.home.homeDirectory}/.config/fish/themes/fish-catppuccin-macchiato.theme";
    };
  };

  programs.fish = {
    enable = true;

    shellAbbrs = {
      tree = "eza --all --tree --long --color=automatic --level=2";
      h = "cd ~";
      "-" = "cd -";
      ".." = "cd ..";
      "..." = "cd ../..";

      # TODO: Drop tail makati
      os-switch = lib.mkMerge [
        (lib.mkIf pkgs.stdenv.hostPlatform.isLinux "sudo nixos-rebuild switch --flake $HOME/.dotfiles/#makati")
        (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "/run/current-system/sw/bin/darwin-rebuild switch --flake ~/.dotfiles/#manila --impure")
      ];
      hm-switch = "home-manager switch --flake $HOME/.dotfiles/#makati";
      fnix-shell = "nix-shell --run fish";

      brew = "/opt/homebrew/bin/brew";
      dprune = "docker system prune --volumes -fa";

      k = "kubectl";
      kctx = "kubectx";
      kns = "kubens";
    };

    shellAliases = {
      reload = "exec fish";
      grep = "grep --color=auto";
      diff = "difft";
      duf = "du -sh * | sort -hr";
      less = "less -r";
      cat = "bat";
      top = "sudo htop";
      vim = "nvim";
      vi = "nvim";

      t = "tmux attach || tmux new-session"; # Attaches tmux to the last session; creates a new session if none exists.
      ta = "tmux attach -t"; # Attaches tmux to a session (example: ta portal)
      tn = "tmux new-session"; # Creates a new session
      tl = "tmux list-sessions"; # Lists all ongoing sessions

      ls = "eza --git --color=automatic";
      ll = "eza --all --long --git --color=automatic";
      la = "eza --all --binary --group --header --long --git --color=automatic";
      l = "la";

      # See forgit - https://github.com/wfxr/forgit
      # ga = "git add' # replaced by forgit";
      # gd = "git diff' # replaced by forgit";
      gl = "git log --graph --decorate --oneline --abbrev-commit";
      glga = "gl --all";
      gp = "git pull";
      gpush = "git push";
      gc = "git commit";
      gco = "git checkout";
      gb = "git branch -v";
      gs = "git status -b";
      gd = "git diff";

      gpph = "git push personal HEAD";
      gpst = "git push origin HEAD:staging-test";
      cdr = "cd $(git rev-parse --show-toplevel)";
    };

    functions = {
      backup_ssh = {
        description = "Backs up the ~/.ssh folder";
        body = "sh ~/.dotfiles/scripts/ssh-backup.sh -h $hostname";
      };

      restore_ssh = {
        description = "Restores a tar file to the ~/.ssh folder";
        body = "sh ~/.dotfiles/scripts/ssh-restore.sh -f $argv[1]";
      };

      backup_local_config = {
        description = "Backs up the ~/.local folder";
        body = "sh ~/.dotfiles/scripts/local-config-backup.sh -h $hostname";
      };

      restore_local_config = {
        description = "Restores a tar file to the ~/.local folder";
        body = "sh ~/.dotfiles/scripts/local-config-restore.sh -f $argv[1]";
      };

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

      encode = {
        description = "Encodes a string to base64";
        body = ''
          echo -n "$argv[1]" | base64
        '';
      };

      decode = {
        description = "Decodes a string from base64";
        body = ''
          echo "$argv[1]" | base64 -D
        '';
      };

      fish_greeting = {
        description = "Override default greeting";
        body = "";
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

    interactiveShellInit = ''
      fzf_configure_bindings --directory=\ct
      set -Ux fzf_fd_opts --hidden --exclude=.git --exclude=Library
      set -Ux FZF_DEFAULT_OPTS "\
      --height=80% --layout=reverse --info=inline --border --margin=1 --padding=1 \
      --color=bg+:#363a4f,bg:#24273a,spinner:#f4dbd6,hl:#ed8796 \
      --color=fg:#cad3f5,header:#ed8796,info:#c6a0f6,pointer:#f4dbd6 \
      --color=marker:#f4dbd6,fg+:#cad3f5,prompt:#c6a0f6,hl+:#ed8796"

      set -Ux FORGIT_LOG_FZF_OPTS "--reverse"
      set -Ux FORGIT_GLO_FORMAT "%C(auto)%h%d %s %C(blue)%an %C(green)%C(bold)%cr"

      # TODO: Setup GOBIN elswhere, also define $HOME
      # set GOBIN "$HOME/go/bin"
      # fish_add_path -pmP $HOME/go/bin

      # TODO: Add brew to path if darwin
      # fish_add_path -pmP /opt/homebrew/bin
    '';

    plugins = [
      {
        name = "fish-fzf";
        src = pkgs.fetchFromGitHub {
          owner = "PatrickF1";
          repo = "fzf.fish";
          rev = "8d99f0caa30a626369541f80848ffdbf28e96acc";
          sha256 = "sha256-CqRSkwNqI/vdxPKrShBykh+eHQq9QIiItD6jWdZ/DSM=";
        };
      }
      {
        name = "fish-foreign-env";
        src = pkgs.fetchFromGitHub {
          owner = "oh-my-fish";
          repo = "plugin-foreign-env";
          rev = "7f0cf099ae1e1e4ab38f46350ed6757d54471de7";
          sha256 = "sha256-4+k5rSoxkTtYFh/lEjhRkVYa2S4KEzJ/IJbyJl+rJjQ=";
        };
      }
      {
        name = "fish-forgit";
        src = pkgs.fetchFromGitHub {
          owner = "wfxr";
          repo = "forgit";
          rev = "48e91dadb53f7ac33cab238fb761b18630b6da6e";
          sha256 = "sha256-WvJxjEzF3vi+YPVSH3QdDyp3oxNypMoB71TAJ7D8hOQ=";
        };
      }
      {
        name = "fish-abbreviation-tips";
        src = pkgs.fetchFromGitHub {
          owner = "Gazorby";
          repo = "fish-abbreviation-tips";
          rev = "8ed76a62bb044ba4ad8e3e6832640178880df485";
          sha256 = "sha256-F1t81VliD+v6WEWqj1c1ehFBXzqLyumx5vV46s/FZRU=";
        };
      }
    ];
  };
}
