# Ported from modules/home/git.nix + delta.nix + difftastic.nix — git plus its
# pager (delta) and structural differ (difftastic), since they configure one
# tool. NOTE: this sets the full git config; the per-user identity (user.name /
# user.email + the per-org includeIf lines) comes from the
# ~/.config/git/gitconfig.local include below — a sops secret on real hosts
# (secrets/home.nix), forwarded into sandvm guests as a launch credential
# (microvm-guest.nix, sandvm-gitconfig) so it never enters the /nix/store.
{
  den.aspects.dev.git.homeManager = {
    programs.git = {
      enable = true;

      settings = {
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
          pom = "push origin main";
          lt = "log --tags --decorate --simplify-by-decoration --oneline";
          lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
          info = "for-each-ref --sort=committerdate refs/heads/ --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(color:red)%(objectname:short)%(color:reset) - %(contents:subject) - %(authorname) (%(color:green)%(committerdate:relative)%(color:reset))'";
        };

        init.defaultBranch = "main";
        core.autocrlf = "input";
        pull.rebase = true;
        help.autocorrect = 1;
        grep.lineNumber = true;
        merge.conflictstyle = "zdiff3";
        diff.colorMoved = "default";
        url."git@github.com:".insteadOf = "https://github.com/";
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
        "node_modules/"
        ".yarn_cache/"
        "Library/"
        ".Trash/"
      ];

      includes = [ { path = "~/.config/git/gitconfig.local"; } ];

      lfs.enable = true;
    };
  };
}
