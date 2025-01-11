{
  programs.starship = {
    enable = true;
    # Configuration written to ~/.config/starship.toml
    settings = {
      add_newline = true;
      format = "$time$username$hostname$nix_shell$directory$git_branch$git_commit$git_state$git_status$env_var$cmd_duration$custom$line_break$jobs$character";
      username = {format = "[$user]($style) in ";};
      directory = {
        format = "in [$path]($style)[$read_only]($read_only_style) ";
        truncate_to_repo = false;
        fish_style_pwd_dir_length = 1;
      };
      hostname = {
        ssh_only = true;
        ssh_symbol = "🌐 ";
        format = "[$ssh_symbol<$hostname>]($style) ";
      };
      time = {
        disabled = false;
        format = "[$time]($style) ";
        time_format = "[%D %R]";
        style = "mauve";
      };
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
        vicmd_symbol = "[➜](bold green)";
      };
      container = {
        disabled = false;
        format = "[$symbol \[$name\]]($style) ";
        style = "bold red dimmed";
        symbol = "⬢";
      };
      nix_shell = {
        format = "[$symbol]($style)";
        symbol = "";
      };
      palette = "catppuccin-macchiato";
      palettes = {
        # copied from https://github.com/catppuccin/starship
        catppuccin-macchiato = {
          rosewater = "#f4dbd6";
          flamingo = "#f0c6c6";
          pink = "#f5bde6";
          mauve = "#c6a0f6";
          red = "#ed8796";
          maroon = "#ee99a0";
          peach = "#f5a97f";
          yellow = "#eed49f";
          green = "#a6da95";
          teal = "#8bd5ca";
          sky = "#91d7e3";
          sapphire = "#7dc4e4";
          blue = "#8aadf4";
          lavender = "#b7bdf8";
          text = "#cad3f5";
          subtext1 = "#b8c0e0";
          subtext0 = "#a5adcb";
          overlay2 = "#939ab7";
          overlay1 = "#8087a2";
          overlay0 = "#6e738d";
          surface2 = "#5b6078";
          surface1 = "#494d64";
          surface0 = "#363a4f";
          base = "#24273a";
          mantle = "#1e2030";
          crust = "#181926";
        };
      };
    };
  };
}
