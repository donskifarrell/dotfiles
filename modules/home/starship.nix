{
  config.flake.homeModules.starship = {
    config = {
      programs.starship = {
        enable = true;
        enableFishIntegration = true;
        settings = {
          add_newline = true;
          format = "$time$username$hostname$nix_shell$directory$git_branch$git_commit$git_state$git_status$direnv$env_var$status$cmd_duration$custom$line_break$jobs$character";
          username = {
            format = "[$user]($style) in ";
          };
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
        };
      };
    };
  };
}
