{
  config.flake.homeModules.fish =
    { pkgs, ... }:
    {
      config = {
        programs.fish = {
          enable = true;

          interactiveShellInit = ''
            fzf_configure_bindings --directory=\ct
            set -Ux fzf_fd_opts --hidden --exclude=.git --exclude=Library
            set -Ux FZF_DEFAULT_OPTS "\
            --height=80% --layout=reverse --info=inline --border --margin=1 --padding=1"

            set -Ux FORGIT_LOG_FZF_OPTS "--reverse"
            set -Ux FORGIT_GLO_FORMAT "%C(auto)%h%d %s %C(blue)%an %C(green)%C(bold)%cr"
          '';

          shellAbbrs = {
            h = "cd ~";
            "-" = "cd -";
            ".." = "cd ..";
            "..." = "cd ../..";

            # os-switch = "nh os switch ~/.dotfiles";
            os-list-gens = "nix profile history --profile /nix/var/nix/profiles/system";
            os-wipe-gens = "sudo nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than 14d";
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

            ltree = "${pkgs.eza}/bin/eza --all --tree --long --color=automatic --level=2";
            ldirs = "${pkgs.eza}/bin/eza --D --icons=auto";
            ls = "${pkgs.eza}/bin/eza --git --color=automatic";
            ll = "${pkgs.eza}/bin/eza --all --long --git --color=automatic";
            la = "${pkgs.eza}/bin/eza --all --binary --group --header --long --git --color=automatic";
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

          plugins = [
            {
              name = "fish-fzf";
              src = pkgs.fetchFromGitHub {
                owner = "PatrickF1";
                repo = "fzf.fish";
                rev = "8920367cf85eee5218cc25a11e209d46e2591e7a";
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
                rev = "76506fc3da3cc5a720dce0084816f3be83d548cb";
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
      };
    };
}
