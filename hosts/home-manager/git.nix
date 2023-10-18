{
  pkgs,
  lib,
  ...
}: {
  git = {
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
      core = {
        editor = "nvim";
        autocrlf = "input";
      };
      pull = {rebase = true;};
      help = {autocorrect = 1;};
      grep = {lineNumber = true;};
      merge = {conflictstyle = "diff3";};
      diff = {colorMoved = "default";};
      url = {"git@github.com:" = {insteadOf = "https://github.com/";};};
    };
    lfs = {
      enable = true;
    };
  };
}
