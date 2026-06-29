{
  inputs,
  den,
  lib,
  ...
}:
{
  # Wire Den in. This works under flake-parts (it brings its own schema/policies).
  # imports = [ inputs.den.flakeModule ];

  # Global static defaults applied to every host/user in this flake.
  den.default = {
    includes = [
      den.batteries.define-user
      den.batteries.hostname
    ];
  };

  # Enable home-manager for every declared user by default
  den.schema.user.classes = lib.mkDefault [ "homeManager" ];
}
