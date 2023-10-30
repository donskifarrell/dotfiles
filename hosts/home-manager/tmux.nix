{
  config,
  lib,
  pkgs,
  user,
  ...
}: {
  programs.tmux = {
    enable = true;
    shortcut = "a";
    terminal = "screen-256color";
    shell = lib.mkMerge [
      (lib.mkIf pkgs.stdenv.hostPlatform.isLinux "${config.home.homeDirectory}/.nix-profile/bin/fish")
      (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "/Users/${user}/.nix-profile/bin/fish")
    ];
    clock24 = true;
    keyMode = "vi";
    escapeTime = 0; # address vim mode switching delay (http://superuser.com/a/252717/65504)
    historyLimit = 100000; # scrollback size
    mouse = true;

    extraConfig = ''
      # ----------------------
      # Settings
      # -----------------------

      # set first window to index 1 (not 0) to map more to the keyboard layout
      set -g base-index 1
      set -g pane-base-index 1

      # Enable focus events.
      set -g focus-events on

      # Automatically rename window titles.
      setw -g automatic-rename on
      set -g set-titles on

      # Automatically renumber windows when a window is closed.
      set -g renumber-windows on

      # Visual Activity Monitoring between windows
      setw -g monitor-activity on
      set -g visual-activity off

      # ----------------------
      # Styling & Status Bar
      # -----------------------

      set-option -g status on
      set -g status-position top
      set -g status-interval 5    # set update frequencey (default 15 seconds)

      # ----------------------
      # Key Bindings
      # -----------------------

      # # Keep your finger on ctrl, or don't, same result
      bind-key C-d detach-client
      bind-key C-p paste-buffer

      # Ctrl - t or t new window
      unbind t
      unbind C-t
      bind-key t new-window -c "#{pane_current_path}"
      bind-key C-t new-window -c "#{pane_current_path}"

      # CTRL + 'i' splits horizontally.
      bind i split-window -h -c "#{pane_current_path}"
      # CTRL + '-' splits vertically.
      bind - split-window -v -c "#{pane_current_path}"

      # Ctrl - z to zoom pane
      unbind-key C-z
      bind-key -n C-z resize-pane -Z

      # Prefix + Ctrl - z to find window
      bind-key C-z command-prompt "find-window '%%'"

      # unbind Ctrl - f so we can use it for fzf
      unbind-key -n C-f

      # Ctrl - w or w to kill panes
      unbind w
      unbind C-w
      bind-key w kill-pane
      bind-key C-w kill-pane

      # C + control q to kill session
      unbind q
      unbind C-q
      bind-key q kill-session
      bind-key C-q kill-session

      # Shift - L/R arrow to switch windows
      unbind M-Left
      unbind M-Right
      bind -n S-Left previous-window
      bind -n S-Right next-window

      # OSX Specific Settings
      ${
        if pkgs.stdenv.hostPlatform.isDarwin
        then "set -s copy-command 'pbcopy'"
        else ""
      }
    '';

    plugins = with pkgs; [
      tmuxPlugins.cpu
      {
        plugin = tmuxPlugins.catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavour 'macchiato'

          set -g @catppuccin_window_default_fill "number"
          set -g @catppuccin_window_default_text " #W " # use "#W" for application instead of directory

          set -g @catppuccin_window_current_fill "number"
          set -g @catppuccin_window_current_text " #W "

          set -g @catppuccin_window_left_separator "█"
          set -g @catppuccin_window_middle_separator "█"
          set -g @catppuccin_window_right_separator ""
        '';
      }
      {
        plugin = tmuxPlugins.resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-nvim 'session'
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-pane-contents-area 'visible'
          set -g @resurrect-dir '~/.local/tmux/resurrect'
        '';
      }
      {
        plugin = tmuxPlugins.continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-boot 'on'
          set -g @continuum-boot-options 'alacritty'
          set -g @continuum-save-interval '5' # minutes
        '';
      }
      {
        plugin = tmuxPlugins.open;
        extraConfig = ''
          set -g @open-S 'https://www.duckduckgo.com/?q='
        '';
      }
      {
        plugin = tmuxPlugins.better-mouse-mode;
        extraConfig = ''
        '';
      }
    ];
  };
}
