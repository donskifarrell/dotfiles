{
  config,
  lib,
  pkgs,
  ...
}:
let
  homeDir = config.me.homeDir;
in
{
  programs.alacritty = {
    enable = true;

    settings = {
      general = {
        live_config_reload = true;
      };
      env = {
        TERM = "alacritty";
      };
      window = {
        decorations = "full";
        startup_mode = "Windowed";
        dynamic_title = true;
        class = {
          instance = "Alacritty";
          general = "Alacritty";
        };
      };
      scrolling = {
        history = 10000;
      };
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
        size = lib.mkMerge [
          (lib.mkIf pkgs.stdenv.hostPlatform.isLinux 12)
          (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin 14)
        ];
        builtin_box_drawing = true;
      };
      colors = {
        draw_bold_text_with_bright_colors = false;
      };
      # terminal = {
      #   shell = {
      #     # program = lib.mkMerge [
      #     #   (lib.mkIf pkgs.stdenv.hostPlatform.isLinux "${homeDir}/.nix-profile/bin/fish")
      #     #   (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "/Users/${user}/.nix-profile/bin/fish")
      #     # ];
      #     args = [ "--login" ];
      #   };
      # };
      hints = {
        alphabet = "jfkdls;ahgurieowpq";
        enabled = [
          {
            regex = ''(ipfs:|ipns:|magnet:|mailto:|gemini:|gopher:|https:|http:|news:|file:|git:|ssh:|ftp:)[^\u0000-\u001F\u007F-\u009F<>"\\s{-}\\^⟨⟩`]+'';
            command = lib.mkMerge [
              (lib.mkIf pkgs.stdenv.hostPlatform.isLinux "${homeDir}/.nix-profile/bin/xdg-open")
              (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "open")
            ];
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
      keyboard.bindings =
        let
          base_key_bindings = [
            {
              key = "V";
              mods = "Control";
              action = "Paste";
            }
            {
              key = "C";
              mods = "Control|Shift";
              action = "Copy";
            }
          ];

          osx_key_bindings = [
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
        in
        base_key_bindings ++ (if pkgs.stdenv.hostPlatform.isDarwin then osx_key_bindings else [ ]);
    };
  };
}
