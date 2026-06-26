# apps/dev/git/github — GitHub CLI (gh) over SSH, with fzf/search extensions and
# the gh-dash TUI dashboard. Ported from sini-nix
# modules/den/aspects/apps/dev/git/github.nix; the gh-dash PR sections were
# trimmed from sini's nixpkgs-maintainer filters down to generic "mine / to
# review / involved" views.
{
  den.aspects.dev.git.github.homeManager =
    { pkgs, ... }:
    {
      programs = {
        gh = {
          enable = true;
          settings.git_protocol = "ssh";
          extensions = [
            pkgs.gh-dash # PR/issue dashboard
            pkgs.gh-f # fzf integration
            pkgs.gh-s # search
          ];
        };

        gh-dash = {
          enable = true;
          settings = {
            prSections = [
              {
                title = "My PRs";
                filters = "is:open author:@me";
              }
              {
                title = "Needs my review";
                filters = "is:open review-requested:@me";
              }
              {
                title = "Involved";
                filters = "is:open involves:@me -author:@me";
              }
            ];
            defaults = {
              prsLimit = 25;
              issuesLimit = 10;
              view = "prs";
              preview = {
                open = false;
                width = 100;
              };
              refetchIntervalMinutes = 10;
            };
            theme.ui.table.showSeparator = false;
          };
        };
      };
    };
}
