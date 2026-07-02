# delta — git pager
{
  den.aspects.shell.delta.homeManager = {
    programs.delta = {
      enable = true;

      options = {
        dark = true;
        features = "decorations";
        line-numbers = true;
        navigate = true;
        side-by-side = true;
        whitespace-error-style = "22 reverse";
      };
    };
  };
}
