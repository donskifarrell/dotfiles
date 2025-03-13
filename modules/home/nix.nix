{
  # TODO: Is this needed any more?
  # Nix configuration is managed globally by nix-darwin.
  # Prevent $HOME nix.conf from disrespecting it.
  # home.file."~/.config/nix/nix.conf".text = "";

  nixpkgs = {
    config = {
      allowBroken = true;
      allowUnsupportedSystem = true;
      allowUnfree = true;

      permittedInsecurePackages = [
      ];

      # allowUnfreePredicate =
      #   pkg:
      #   builtins.elem (lib.getName pkg) [
      #   ];
    };
  };
}
