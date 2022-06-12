# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)

{ inputs, lib, config, pkgs, username, hostname, ... }: {
  imports = [
    # If you want to use home-manager modules from other flakes (such as nix-colors), use something like:
    # inputs.nix-colors.homeManagerModule

    # Feel free to split up your configuration and import pieces of it here.
    ../common/home-base.nix
  ];

  home = {
    # Different location on OSX
    homeDirectory = pkgs.lib.mkForce "/Users/${config.home.username}";

    packages = [
      pkgs.go
      pkgs.gopls

      pkgs.ffmpeg
    ];
  };

  programs.git = {
    includes = [
      { path = "~/.dotfiles/hosts/${hostname}/.gitconfig.local"; }
      {
        path = ".gitconfig.brankas";
        condition = "gitdir/i:brankas/";
      }
      {
        path = ".gitconfig.brankas";
        condition = "gitdir/i:brank.as/";
      }
    ];
  };
  
  programs.fish = {
    loginShellInit = ''
      if test -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        fenv source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
      end

      if test -e /nix/var/nix/profiles/default/etc/profile.d/nix.sh
        fenv source /nix/var/nix/profiles/default/etc/profile.d/nix.sh
      end
    '';
  };

  programs.alacritty = {
    enable = true;

    settings = {
    env = {
        TERM = "alacritty";
    };
    window = {
        decorations = "full";
        startup_mode = "Windowed";
    };
    scrolling = {
        history = 10000;
    };
    font = {
        normal = {
            family = "JetBrains Mono";
            style = "Regular";
        };
        bold = {
            family = "JetBrains Mono";
            style = "Bold";
        };
        italic = {
            family = "JetBrains Mono";
            style = "Italic";
        };
        bold_italic = {
            family = "JetBrains Mono";
            style = "Bold Italic";
        };
        size = 12;
        use_thin_strokes = true;
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
        search = {
            matches = {
                foreground = "#44475a";
                background = "#50fa7b";
            };
            focused_match = {
                foreground = "#44475a";
                background = "#ffb86c";
            };
            bar = {
                background = "#282a36";
                foreground = "#f8f8f2";
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
    cursor = {
        unfocused_hollow = true;
    };
    live_config_reload = true;
    shell = {
        program = "/Users/$USER/.nix-profile/bin/fish";
    };
    mouse = null;
    hints = {
        alphabet = "jfkdls;ahgurieowpq";
        enabled = [
            {
                regex = "(ipfs:|ipns:|magnet:|mailto:|gemini:|gopher:|https:|http:|news:|file:|git:|ssh:|ftp:)[^\u0000-\u001f-<>\"\\s{-}\\^⟨⟩`]+";
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
            chars = "\f";
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
  home.stateVersion = "22.05";
}
