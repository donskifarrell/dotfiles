{ inputs, ... }:
{
  imports = [
    (inputs.git-hooks + /flake-module.nix)
  ];
  perSystem =
    {
      inputs',
      config,
      pkgs,
      ...
    }:
    {
      devShells.default = pkgs.mkShell {
        name = "nixos-config-shell";
        meta.description = "Shell environment for modifying this Nix configuration";
        inputsFrom = [ config.pre-commit.devShell ];
        packages = with pkgs; [
          just
          nixd
          dconf2nix
          inputs'.agenix.packages.default
        ];
      };

      pre-commit.settings = {
        hooks.nixfmt-rfc-style.enable = true;
      };
    };
}
