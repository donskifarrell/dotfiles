{
  pkgs,
  lib,
  user,
  ...
}: {
  alacritty = {
    enable = true;

    settings = {
      env = {TERM = "alacritty";};
      import = lib.mkMerge [
        (lib.mkIf pkgs.stdenv.hostPlatform.isLinux ["/home/${user}/.dotfiles/shared/config/theme/alacritty-catppuccin-macchiato.yml"])
        (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin ["/Users/${user}/.dotfiles/shared/config/theme/alacritty-catppuccin-macchiato.yml"])
      ];
      window = {
        decorations = "full";
        startup_mode = "Windowed";
        dynamic_title = true;
        class = {
          instance = "Alacritty";
          general = "Alacritty";
        };
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
        size = lib.mkMerge [
          (lib.mkIf pkgs.stdenv.hostPlatform.isLinux 12)
          (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin 14)
        ];
        builtin_box_drawing = true;
      };
      draw_bold_text_with_bright_colors = false;
      live_config_reload = true;
      shell = {
        program = lib.mkMerge [
          (lib.mkIf pkgs.stdenv.hostPlatform.isLinux "/etc/profiles/per-user/${user}/bin/fish")
          (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "/Users/${user}/.nix-profile/bin/fish")
        ];
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
    };
  };
}
