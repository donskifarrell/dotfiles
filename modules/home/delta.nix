{
  config.flake.homeModules.delta = {
    config = {
      programs.delta = {
        enable = true;

        options = {
          navigate = true;
          features = "decorations";
          whitespace-error-style = "22 reverse";
        };
      };
    };
  };
}
