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
  imports = [
    # If you want to use home-manager modules from other flakes (such as nix-colors), use something like:
    # inputs.nix-colors.homeManagerModule

    # Feel free to split up your configuration and import pieces of it here.
    ../common/home-base.nix
  ];

  # Workaround fix: https://github.com/nix-community/home-manager/issues/2942
  nixpkgs.config.allowUnfreePredicate = pkg: true;
  fonts.fontconfig.enable = true;

  home = {
    # Different location on OSX
    homeDirectory = pkgs.lib.mkForce "/Users/${config.home.username}";

    packages = with pkgs; [
      ffmpeg
      go
      gopls
      google-cloud-sdk # Issues with auth plugin. Check out https://github.com/jgresty/gcloud-components-nix
      kubectl
      kubectx
      (nerdfonts.override {fonts = ["JetBrainsMono"];})
      git-filter-repo
      nodejs
    ];
  };

  programs.go = {
    enable = true;
    package = pkgs.go;
    goPath = "go";
  };

  programs.vscode = {
    enable = true;
    mutableExtensionsDir = true;

    extensions = with pkgs; [
      vscode-extensions.golang.go
      vscode-extensions.kamadorueda.alejandra
      vscode-extensions.bbenoist.nix
      vscode-extensions.formulahendry.auto-close-tag
      vscode-extensions.formulahendry.auto-rename-tag
      vscode-extensions.tamasfe.even-better-toml
      vscode-extensions.dracula-theme.theme-dracula
      vscode-extensions.dbaeumer.vscode-eslint
      vscode-extensions.hashicorp.terraform
      vscode-extensions.esbenp.prettier-vscode
      vscode-extensions.ms-vscode-remote.remote-ssh
      vscode-extensions.foxundermoon.shell-format
      vscode-extensions.bradlc.vscode-tailwindcss
      vscode-extensions.redhat.vscode-yaml
      vscode-extensions.streetsidesoftware.code-spell-checker
      vscode-extensions.donjayamanne.githistory
      vscode-extensions.jock.svg

      # Not on nixpkgs yet:
      # vscode-extensions.wayou.vscode-todo-highlight
      # vscode-extensions.vscode-icons-team.vscode-icons
      # vscode-extensions.waderyan.gitblame
    ];

    userSettings = {
      "alejandra.program" = "alejandra";
      "diffEditor.ignoreTrimWhitespace" = false;
      "editor.wordWrap" = "on";
      "editor.linkedEditing" = true;
      "editor.formatOnSave" = true;
      "editor.bracketPairColorization.enabled" = true;
      "editor.unicodeHighlight.includeStrings" = false;
      "editor.tabSize" = 2;
      "explorer.confirmDelete" = false;
      "files.trimTrailingWhitespace" = true;
      "files.insertFinalNewline" = true;
      "files.encoding" = "utf8";
      "files.eol" = "\n";
      "git.confirmSync" = false;
      "go.toolsManagement.autoUpdate" = true;
      "go.formatTool" = "gofmt";
      "html.format.enable" = false;
      "[html]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
      "[json]"."editor.defaultFormatter" = "vscode.json-language-features";
      "redhat.telemetry.enabled" = false;
      "vetur.format.defaultFormatter.html" = "none";
      "workbench.iconTheme" = "vscode-icons";
      "workbench.colorTheme" = "Dracula";
      "[nix]"."editor.defaultFormatter" = "kamadorueda.alejandra";
      "[nix]"."editor.formatOnPaste" = true;
      "[nix]"."editor.formatOnSave" = true;
      "[nix]"."editor.formatOnType" = false;
      "[typescript]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
      "shellformat.path" = "/Users/${config.home.username}/.nix-profile/bin/shfmt";
      "remote.SSH.configFile" = "/Users/${config.home.username}/.ssh/sshconfig.local";
      "[dockerfile]"."editor.defaultFormatter" = "ms-azuretools.vscode-docker";
      "files"."associations"."*.tmpl" = "html";

      # TODO: Needed to fix issue with remote SSH failing to connect to VMs
      "remote.SSH.useLocalServer" = false;
      "remote.SSH.remotePlatform"."192.168.64.1" = "linux";
      "remote.SSH.remotePlatform"."192.168.64.2" = "linux";
      "remote.SSH.remotePlatform"."192.168.64.3" = "linux";
      "remote.SSH.remotePlatform"."192.168.64.4" = "linux";
      "remote.SSH.remotePlatform"."192.168.64.5" = "linux";
      "remote.SSH.remotePlatform"."192.168.64.6" = "linux";
      "remote.SSH.remotePlatform"."192.168.64.7" = "linux";
    };
  };

  programs.git = {
    extraConfig = {
      credential = {helper = "osxkeychain";};
    };

    includes = [
      {
        path = "~/.local/git/.gitconfig.brankas";
        condition = "gitdir/i:brankas/";
      }
      {
        path = "~/.local/git/.gitconfig.brankas";
        condition = "gitdir/i:brank.as/";
      }
      {
        path = "~/.local/git/.gitconfig.brankas";
        condition = "gitdir/i:testing/";
      }
      {
        path = "~/.local/git/.gitconfig.polygonstar";
        condition = "gitdir/i:polygonstar/";
      }
    ];
  };

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

      fish_add_path -pmP /opt/homebrew/bin
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
    enable = true;
    # terminal = "alacritty";

    extraConfig = ''
      # ----------------------
      # From home.nix
      # -----------------------

      set -s copy-command 'pbcopy'
    '';
  };

  # TODO: DO NOT RUN THROUGH A FORMATTER! (hints -> enabled -> regex gets borked at the "\\s )
  programs.alacritty = {
    enable = true;

    settings = {
      env = {TERM = "alacritty";};
      window = {
        decorations = "full";
        startup_mode = "Windowed";
      };
      scrolling = {history = 10000;};
      font = {
        normal = {
          family = "JetBrainsMono Nerd Font";
          style = "Regular";
        };
        bold = {
          family = "JetBrainsMono Nerd Font";
          style = "Bold";
        };
        italic = {
          family = "JetBrainsMono Nerd Font";
          style = "Italic";
        };
        bold_italic = {
          family = "JetBrainsMono Nerd Font";
          style = "Bold Italic";
        };
        size = 12;
        builtin_box_drawing = true;
      };
      draw_bold_text_with_bright_colors = false;
      colors = {
        primary = {
          background = "#282a36";
          foreground = "#f8f8f2";
          bright_foreground = "#ffffff";
        };
        cursor = {
          text = "CellBackground";
          cursor = "CellForeground";
        };
        vi_mode_cursor = {
          text = "CellBackground";
          cursor = "CellForeground";
        };
        footer_bar = {
          background = "#282a36";
          foreground = "#f8f8f2";
        };
        search = {
          matches = {
            foreground = "#44475a";
            background = "#50fa7b";
          };
          focused_match = {
            foreground = "#44475a";
            background = "#ffb86c";
          };
        };
        hints = {
          start = {
            foreground = "#282a36";
            background = "#f1fa8c";
          };
          end = {
            foreground = "#f1fa8c";
            background = "#282a36";
          };
        };
        line_indicator = {
          foreground = "None";
          background = "None";
        };
        selection = {
          text = "CellForeground";
          background = "#44475a";
        };
        normal = {
          black = "#21222c";
          red = "#ff5555";
          green = "#50fa7b";
          yellow = "#f1fa8c";
          blue = "#bd93f9";
          magenta = "#ff79c6";
          cyan = "#8be9fd";
          white = "#f8f8f2";
        };
        bright = {
          black = "#6272a4";
          red = "#ff6e6e";
          green = "#69ff94";
          yellow = "#ffffa5";
          blue = "#d6acff";
          magenta = "#ff92df";
          cyan = "#a4ffff";
          white = "#ffffff";
        };
      };
      cursor = {unfocused_hollow = true;};
      live_config_reload = true;
      shell = {
        program = "/Users/${config.home.username}/.nix-profile/bin/fish";
        args = ["--login"];
      };
      hints = {
        alphabet = "jfkdls;ahgurieowpq";
        enabled = [
          {
            # TODO: DO NOT RUN THROUGH A FORMATTER!
            regex = ''
              (ipfs:|ipns:|magnet:|mailto:|gemini:|gopher:|https:|http:|news:|file:|git:|ssh:|ftp:)[^\u0000-\u001F\u007F-\u009F<>"\\s{-}\\^⟨⟩`]+'';
            command = "open";
            post_processing = true;
            mouse = {
              enabled = true;
              mods = "None";
            };
            binding = {
              key = "U";
              mods = "Control|Shift";
            };
          }
        ];
      };
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

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  # home.stateVersion = "22.05";
}
