{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.fish = {
    enable = true;

    shellAbbrs = {
      h = "cd ~";
      "-" = "cd -";
      ".." = "cd ..";
      "..." = "cd ../..";

      os-switch = "nh os switch ~/.dotfiles";
    };

    shellAliases = {
      reload = "exec fish";
      grep = "grep --color=auto";
      diff = "difft";
      duf = "du -sh * | sort -hr";
      less = "less -r";
      cat = "bat";
      top = "sudo btop";
      vim = "nvim";
      vi = "nvim";

      t = "tmux attach || tmux new-session"; # Attaches tmux to the last session; creates a new session if none exists.
      ta = "tmux attach -t"; # Attaches tmux to a session (example: ta portal)
      tn = "tmux new-session"; # Creates a new session
      tl = "tmux list-sessions"; # Lists all ongoing sessions

      ltree = "eza --all --tree --long --color=automatic --level=2";
      ls = "eza --git --color=automatic";
      ll = "eza --all --long --git --color=automatic";
      la = "eza --all --binary --group --header --long --git --color=automatic";
      l = "la";

      # See forgit - https://github.com/wfxr/forgit
      # ga = "git add' # replaced by forgit";
      # gd = "git diff' # replaced by forgit";
      gl = "glo"; # use forgit version
      # gl = "git log --graph --decorate --oneline --abbrev-commit";
      # glga = "gl --all";
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
      set -Ux fzf_fd_opts --hidden --exclude=.git --exclude=Library
      set -Ux FZF_DEFAULT_OPTS "\
      --height=80% --layout=reverse --info=inline --border --margin=1 --padding=1"

      set -Ux FORGIT_LOG_FZF_OPTS "--reverse"
      set -Ux FORGIT_GLO_FORMAT "%C(auto)%h%d %s %C(blue)%an %C(green)%C(bold)%cr"
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
