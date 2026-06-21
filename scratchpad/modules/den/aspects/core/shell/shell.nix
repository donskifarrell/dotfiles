{
  den.aspects.core.shell = {
    os = {
      programs.fish = {
        enable = true;
        # enableCompletion = true;
      };
    };

    nixos =
      { pkgs, ... }:
      {
        environment.enableAllTerminfo = true;
        users.users.root.shell = pkgs.bashInteractive;
        users.defaultUserShell = pkgs.fish;
      };
  };
}
