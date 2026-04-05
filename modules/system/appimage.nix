{
  config.flake.nixosModules.appimage =
    { ... }:
    {
      config = {
        programs.appimage = {
          enable = true;
          binfmt = true;
        };
      };
    };
}
