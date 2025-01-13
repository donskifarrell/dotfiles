{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        name = "nixos-config-shell";
        meta.description = "Shell environment for modifying this Nix configuration";
        packages = with pkgs; [
          dconf2nix
          just
          nixd
        ];
      };
    };
}
