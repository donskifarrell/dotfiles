{
  config,
  pkgs,
  lib,
  system,
  hostname,
  homepath,
  ...
}: {
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "df";
  home.homeDirectory = homepath;
  home.stateVersion = "23.05";

  nixpkgs.config = {
     # Allow unfree packages
     allowUnfree = true;
     # Workaround fix: https://github.com/nix-community/home-manager/issues/2942
     allowUnfreePredicate = pkg: true;
     
     permittedInsecurePackages = [
      "openssl-1.1.1v"
     ];
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello
    age
    alejandra
    cht-sh
    ffmpeg
    git-filter-repo
    go
    gopls
    kubectl
    kubectx
    mkcert
    netperf
    nodejs
    nodePackages_latest.pnpm
    rlwrap
    shfmt

    brave
    chromium
    vivaldi
    firefox
    maestral-gui
    _1password-gui
    gimp
    vlc
    spotify
    mattermost
    obsidian
    sublime4
    vscode
    hunspell
    libreoffice-still

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })
    (google-cloud-sdk.withExtraComponents [google-cloud-sdk.components.gke-gcloud-auth-plugin])
    (nerdfonts.override {fonts = ["JetBrainsMono"];})

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

home.file = let
  autostartPrograms = [ pkgs.ulauncher pkgs._1password-gui ];
in
  
  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  builtins.listToAttrs (map
    (pkg:
      {
	name = ".config/autostart/" + pkg.pname + ".desktop";
	value =
	  if pkg ? desktopItem then {
	    # Application has a desktopItem entry. 
	    # Assume that it was made with makeDesktopEntry, which exposes a
	    # text attribute with the contents of the .desktop file
	    text = pkg.desktopItem.text;
	  } else {
	    # Application does *not* have a desktopItem entry. Try to find a
	    # matching .desktop name in /share/apaplications
	    source = (pkg + "/share/applications/" + pkg.pname + ".desktop");
	  };
      })
    autostartPrograms);
    
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
    #  home.file = {
    # ...
    #  };


  # You can also manage environment variables but you will have to manually
  # source
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/df/etc/profile.d/hm-session-vars.sh
  #
  # if you don't want to manage your shell through Home Manager.
  home.sessionVariables = {
    LANG = "en_GB.UTF-8";
    LC_CTYPE = "en_GB.UTF-8";
    LC_ALL = "en_GB.UTF-8";
    EDITOR = "nvim";
    PAGER = "less -FirSwX";
    MANPAGER = "sh -c 'col -bx | ${pkgs.bat}/bin/bat -l man -p'";
  };

  fonts.fontconfig.enable = true;

  programs.bat.enable = true;
  programs.exa.enable = true;
  programs.fzf.enable = true;

  programs.git = {
    enable = true;

    delta = {
      enable = true;
      options = {
        navigate = true;
        features = "decorations";
        whitespace-error-style = "22 reverse";
      };
    };

    aliases = {
      co = "checkout";
      st = "status";
      br = "branch";
      po = "push origin";
      pp = "push personal";
      count = "shortlog -sn";
      g = "grep --break --heading --line-number";
      gi = "grep --break --heading --line-number -i";
      changed = ''show --pretty="format:" --name-only'';
      please = "push --force-with-lease";
      commend = "commit --amend --no-editor";
      pom = "push origin master";
      lt = "log --tags --decorate --simplify-by-decoration --oneline";
      lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
      info = "for-each-ref --sort=committerdate refs/heads/ --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(color:red)%(objectname:short)%(color:reset) - %(contents:subject) - %(authorname) (%(color:green)%(committerdate:relative)%(color:reset))'";
    };

    ignores = [
      ".java-version"
      ".DS_Store"
      ".svn"
      "*~"
      "*.swp"
      "*.orig"
      "*.rbc"
      ".idea"
      "*.iml"
      ".classpath"
      ".project"
      ".settings"
      ".ruby-version"
      "dump.rdb"
      "main.tfvars"
      ".vscode/"
      "node_modules/"
      ".yarn_cache/"
      "Library/"
      ".Trash/"
    ];

    includes = [
      {
        path = "~/.local/git/.gitconfig.local";
      }
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

    extraConfig = {
      init = {defaultBranch = "main";};
      core = {editor = "nvim";};
      pull = {rebase = true;};
      help = {autocorrect = 1;};
      grep = {lineNumber = true;};
      merge = {conflictstyle = "diff3";};
      diff = {colorMoved = "default";};
      url = {"git@github.com:" = {insteadOf = "https://github.com/";};};
    };
  };

  programs.fish = {
    enable = true;

    shellAbbrs = {
      tree = "exa --all --tree --long --color=automatic --level=2";
      h = "cd ~";
      "-" = "cd -";
      ".." = "cd ..";
      "..." = "cd ../..";

      hm-switch = "home-manager switch --flake ${homepath}/.dotfiles/#${config.home.username}@${hostname}";
      fnix-shell = "nix-shell --run fish";

      k = "kubectl";
      kctx = "kubectx";
      kns = "kubens";
    };

    shellAliases = {
      reload = "exec fish";
      grep = "grep --color=auto";
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

      ls = "exa --git --color=automatic";
      ll = "exa --all --long --git --color=automatic";
      la = "exa --all --binary --group --header --long --git --color=automatic";
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
    };

    interactiveShellInit = ''
      fzf_configure_bindings --directory=\ct
      set fzf_fd_opts --hidden --exclude=.git --exclude=Library

      set FORGIT_LOG_FZF_OPTS "--reverse"
      set FORGIT_GLO_FORMAT "%C(auto)%h%d %s %C(blue)%an %C(green)%C(bold)%cr"

      set GOBIN "${homepath}/go/bin"
      fish_add_path -pmP ${homepath}/go/bin
    '';

    plugins = [
      {
        name = "fish-fzf";
        src = pkgs.fetchFromGitHub {
          owner = "PatrickF1";
          repo = "fzf.fish";
          rev = "702439613a0b531fa1df2ad1fb2676444cd88307";
          sha256 = "sha256-F2gZwxVbLXDxdkDsnpIns32VsyYj84dA5cJjkqC0ZEo=";
        };
      }
      {
        name = "fish-foreign-env";
        src = pkgs.fetchFromGitHub {
          owner = "oh-my-fish";
          repo = "plugin-foreign-env";
          rev = "b3dd471bcc885b597c3922e4de836e06415e52dd";
          sha256 = "sha256-3h03WQrBZmTXZLkQh1oVyhv6zlyYsSDS7HTHr+7WjY8=";
        };
      }
      {
        name = "fish-dracula";
        src = pkgs.fetchFromGitHub {
          owner = "dracula";
          repo = "fish";
          rev = "62b109f12faab5604f341e8b83460881f94b1550";
          sha256 = "sha256-0TlKq2ur2I6Bv7pu7JObrJxV0NbQhydmCuUs6ZdDU1I=";
        };
      }
      {
        name = "fish-z";
        src = pkgs.fetchFromGitHub {
          owner = "jethrokuan";
          repo = "z";
          rev = "85f863f20f24faf675827fb00f3a4e15c7838d76";
          sha256 = "sha256-+FUBM7CodtZrYKqU542fQD+ZDGrd2438trKM0tIESs0=";
        };
      }
      {
        name = "fish-forgit";
        src = pkgs.fetchFromGitHub {
          owner = "wfxr";
          repo = "forgit";
          rev = "6385f85360b6fe0a1ac19cd5ce595b4f3921a2a7";
          sha256 = "sha256-sWWv9UJR1K8Q5ZTcU7xjJtk8hTRXywVjSL2gQ5Kqj0M=";
        };
      }
      {
        name = "fish-abbreviation-tips";
        src = pkgs.fetchFromGitHub {
          owner = "Gazorby";
          repo = "fish-abbreviation-tips";
          rev = "d29a52375a0826ed86b0710f58b2495a73d3aff3";
          sha256 = "sha256-841GmOAi/KS7HF7G29NUD8swaTTCPGdpIUV7B2ln32g=";
        };
      }
    ];
  };

  programs.neovim = {
    enable = true;

    # extraConfig = builtins.concatStringsSep "\n" [
    #   (lib.strings.fileContents ./neovim/config.vim)

    #   ''
    #     lua << EOF
    #     ${lib.strings.fileContents ./neovim/config.lua}
    #     EOF
    #   ''
    # ];

    # extraPackages = with pkgs; [
    #   # installs different langauge servers for neovim-lsp
    #   # have a look on the link below to figure out the ones for your languages
    #   # https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
    #   nodePackages.typescript
    #   nodePackages.typescript-language-server

    #   shfmt
    #   gopls
    #   rnix-lsp
    # ];

    # plugins = with pkgs.vimPlugins; [
    #   vim-tmux-navigator
    #   nvim-lspconfig
    #   nvim-ts-rainbow
    #   nvim-ts-autotag
    #   The_NERD_Commenter
    #   fzf-vim
    #   vim-repeat
    #   # vim-surround # Conflicts with nerd commenter keys?
    #   vim-gitgutter # Need to customise colours
    #   vim-fugitive
    #   nvim-web-devicons
    #   lualine-nvim
    #   bufferline-nvim
    #   nvim-tree-lua
    #   nvim-colorizer-lua
    #   which-key-nvim

    #   (nvim-treesitter.withPlugins (
    #     # https://github.com/NixOS/nixpkgs/tree/nixos-unstable/pkgs/development/tools/parsing/tree-sitter/grammars
    #     plugins:
    #       with plugins; [
    #         tree-sitter-lua
    #         tree-sitter-html
    #         tree-sitter-yaml
    #         tree-sitter-json
    #         tree-sitter-markdown
    #         tree-sitter-comment
    #         tree-sitter-bash
    #         tree-sitter-javascript
    #         tree-sitter-nix
    #         tree-sitter-typescript
    #         tree-sitter-query # for the tree-sitter itself
    #         tree-sitter-python
    #         tree-sitter-go
    #         tree-sitter-sql
    #         tree-sitter-graphql
    #         tree-sitter-dockerfile
    #         tree-sitter-fish
    #       ]
    #   ))
    # ];
  };

  programs.ssh = {
    enable = true;

    includes = ["~/.ssh/sshconfig.local"];
  };

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
        style = "#AE42B5";
      };
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
        vicmd_symbol = "[➜](bold green)";
      };
      nix_shell = {
        format = "[$symbol$state( \($name\) )]($style)";
        symbol = "";
      };
    };
  };

  programs.tmux = {
    enable = true;
    shortcut = "a";
    terminal = "screen-256color";
    shell = "${homepath}/.nix-profile/bin/fish";
    clock24 = true;
    keyMode = "vi";

    extraConfig = ''
      # ----------------------
      # Settings
      # -----------------------
      set -g default-shell ${homepath}/.nix-profile/bin/fish

      # scrollback size
      set -g history-limit 100000

      # set first window to index 1 (not 0) to map more to the keyboard layout
      set -g base-index 1
      set -g pane-base-index 1

      # Using the mouse to switch panes
      set -g mouse on

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

      # address vim mode switching delay (http://superuser.com/a/252717/65504)
      set -s escape-time 0

      # ----------------------
      # Styling & Status Bar
      # -----------------------

      set-option -g status on
      set -g status-position top
      set -g status-interval 5    # set update frequencey (default 15 seconds)

      # Dracula Color Pallette
      dr_white='#f8f8f2'
      dr_gray='#44475a'
      dr_dark_gray='#282a36'
      dr_light_purple='#bd93f9'
      dr_dark_purple='#6272a4'
      dr_cyan='#8be9fd'
      dr_green='#50fa7b'
      dr_orange='#ffb86c'
      dr_red='#ff5555'
      dr_pink='#ff79c6'
      dr_yellow='#f1fa8c'

      # pane border styling
      set-option -g pane-active-border-style "fg=$dr_dark_purple"
      set-option -g pane-border-style "fg=$dr_gray"

      # message styling
      set-option -g message-style "bg=$dr_gray,fg=$dr_white"

      # status bar
      set-option -g status-style "bg=$dr_gray,fg=$dr_white"

      set-option -g status-left-length 100
      set-option -g status-left "#[bg=$dr_green,fg=$dr_dark_gray]#{?client_prefix,#[bg=$dr_yellow],} ☺ "

      set-option -g status-right-length 100
      set-option -g status-right ""

      set-option -ga status-right "#[fg=$dr_dark_gray,bg=$dr_orange] #(~/.dotfiles/hosts/common/tmux/kubectl-ctx.sh) "
      set-option -ga status-right "#[fg=$dr_white,bg=$dr_dark_purple] #(~/.dotfiles/hosts/common/tmux/net-speed.sh) "
      set-option -ga status-right "#[fg=$dr_dark_gray,bg=$dr_cyan] #(~/.dotfiles/hosts/common/tmux/net-interface.sh)  "

      # window tabs
      set-window-option -g window-status-current-format "#[fg=$dr_white,bg=$dr_dark_purple] #I #W #{?window_zoomed_flag,🔍 , }"
      set-window-option -g window-status-format "#[fg=$dr_white]#[bg=$dr_gray] #I #W #{?window_zoomed_flag,🔍 , }"

      # ----------------------
      # Key Bindings
      # -----------------------

      # # Keep your finger on ctrl, or don't, same result
      bind-key C-d detach-client
      bind-key C-p paste-buffer

      # reload tmux config with ctrl + a + o
      unbind o
      bind o \
          source-file ~/.config/tmux/tmux.conf \;\
              display 'Reloaded tmux config.'

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
    '';

    plugins = with pkgs; [
      tmuxPlugins.cpu
      {
        plugin = tmuxPlugins.resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-nvim 'session'
          set -g @resurrect-capture-pane-contents 'on'
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
          set -g @continuum-restore 'on'
          set -g @continuum-boot 'on'
          set -g @continuum-save-interval '5' # minutes
        '';
      }
      {
        plugin = tmuxPlugins.better-mouse-mode;
        extraConfig = ''
        '';
      }
    ];
  };

  programs.go = {
    enable = true;
    package = pkgs.go;
    goPath = "go";
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
        program = "${homepath}/.nix-profile/bin/fish";
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
}