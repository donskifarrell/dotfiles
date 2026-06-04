{
  inputs,
  den,
  lib,
  ...
}:
{
  # Wire Den in. This works under flake-parts (it brings its own schema/policies).
  imports = [ inputs.den.flakeModule ];

  # Global static defaults applied to every host/user in this flake.
  den.default = {
    nixos.system.stateVersion = "26.05";
    homeManager.home.stateVersion = "26.05";

    includes = [
      den.batteries.hostname # networking.hostName <- den.hosts.<name>
      den.batteries.define-user # create each host's users at OS + HM level
    ];
  };

  # Enable home-manager for every declared user by default (matches the
  # upstream `example` template). Single user `df` inherits this.
  den.schema.user.classes = lib.mkDefault [ "homeManager" ];
}
