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

      ltree = "eza --all --tree --long --color=automatic --level=2";
      ls = "eza --git --color=automatic";
      ll = "eza --all --long --git --color=automatic";
      la = "eza --all --binary --group --header --long --git --color=automatic";
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
  };
}
