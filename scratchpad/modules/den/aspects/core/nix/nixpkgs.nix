{
  inputs,
  self,
  ...
}:
let
  config = {
    allowUnfree = true;
    allowDeprecatedx86_64Darwin = true;
  };
in
{
  den.aspects.core.nix.nixpkgs = {
    os.nixpkgs = {
      inherit config;
    };

    homeManager.nixpkgs = {
      inherit config;
    };
  };
}
